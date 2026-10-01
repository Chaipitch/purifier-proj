import { LightningElement, api, wire } from "lwc";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import TIME_ZONE from "@salesforce/i18n/timeZone";
import getChat from "@salesforce/apex/NoritzLineChatController.getChat";
import sendMessage from "@salesforce/apex/NoritzLineChatController.sendMessage";
import getTemplates from "@salesforce/apex/NoritzLineChatController.getTemplates";

const CHANNEL = "/event/LINE_Chat_Refresh__e";
const FALLBACK_POLL_SECONDS = 3;
const URL_PATTERN = /https:\/\/\S+/;
const LINK_TYPES = new Set(["Checkout Link", "Payment Retry"]);

const timeFormat = new Intl.DateTimeFormat("en-GB", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
  timeZone: TIME_ZONE
});

function errorText(error) {
  return error?.body?.message || error?.message || "Something went wrong.";
}

export default class NoritzLineChat extends LightningElement {
  @api recordId;
  // Refresh normally comes from the platform event; set this (seconds) to force polling instead.
  @api pollingInterval = 0;

  customerName;
  lineUserId;
  // The Account or Lead whose conversation this is (a Case page shows its Account's chat).
  chatOwnerId;
  noCustomer = false;
  templates = [];
  rawMessages = [];
  draft = "";
  isLoading = true;
  isSending = false;
  loadError;

  subscription;
  pollTimer;
  scrollPending = false;

  @wire(getTemplates, { recordId: "$recordId" })
  wiredTemplates({ data }) {
    this.templates = (data || []).map((t, i) => ({
      value: String(i),
      label: t.label,
      body: t.body
    }));
  }

  connectedCallback() {
    this.loadChat();
    if (this.pollingInterval > 0) {
      this.startPolling(this.pollingInterval);
    } else {
      this.subscribeToRefresh();
    }
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = undefined;
    }
    this.stopPolling();
  }

  renderedCallback() {
    if (this.scrollPending && this.refs.scroller) {
      this.refs.scroller.scrollTop = this.refs.scroller.scrollHeight;
      this.scrollPending = false;
    }
  }

  async loadChat() {
    try {
      const data = await getChat({ recordId: this.recordId });
      const grew = data.messages.length !== this.rawMessages.length;
      this.customerName = data.customerName;
      this.lineUserId = data.lineUserId;
      this.chatOwnerId = data.chatOwnerId;
      this.noCustomer = data.noCustomer;
      this.rawMessages = data.messages;
      this.loadError = undefined;
      if (grew) {
        this.scrollPending = true;
      }
    } catch (error) {
      this.loadError = errorText(error);
    } finally {
      this.isLoading = false;
    }
  }

  subscribeToRefresh() {
    onError(() => this.startPolling(FALLBACK_POLL_SECONDS));
    subscribe(CHANNEL, -1, (event) => {
      const changedId = event?.data?.payload?.Account_Id__c;
      if (
        changedId &&
        (changedId === this.chatOwnerId || changedId === this.recordId)
      ) {
        this.loadChat();
        // Server-side changes (e.g. the payment failure flow) don't reach the standard
        // highlights panel or Path on their own; this makes the page re-read the record.
        notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      }
    })
      .then((sub) => {
        this.subscription = sub;
      })
      .catch(() => this.startPolling(FALLBACK_POLL_SECONDS));
  }

  startPolling(seconds) {
    if (this.pollTimer) {
      return;
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.pollTimer = setInterval(() => this.loadChat(), seconds * 1000);
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = undefined;
    }
  }

  get title() {
    return this.customerName ? `LINE Chat · ${this.customerName}` : "LINE Chat";
  }

  get notLinked() {
    return (
      !this.isLoading && !this.loadError && !this.noCustomer && !this.lineUserId
    );
  }

  get hasTemplates() {
    return this.templates.length > 0 && !this.noCustomer;
  }

  get hasMessages() {
    return this.messages.length > 0;
  }

  get showEmpty() {
    return !this.isLoading && !this.loadError && !this.hasMessages;
  }

  get sendDisabled() {
    return this.isSending || !this.draft.trim();
  }

  get messages() {
    return this.rawMessages.map((m) => {
      const isOutbound = m.Direction__c === "Outbound";
      const body = m.Message_Body__c || "";
      const linkUrl =
        isOutbound && LINK_TYPES.has(m.Message_Type__c)
          ? body.match(URL_PATTERN)?.[0]
          : undefined;
      return {
        id: m.Id,
        text: linkUrl ? body.replace(linkUrl, "").trim() : body,
        time: m.Sent_At__c ? timeFormat.format(new Date(m.Sent_At__c)) : "",
        linkUrl,
        failed: isOutbound && m.Delivery_Status__c === "Failed",
        error: m.Delivery_Error__c,
        rowClass: isOutbound ? "row row_outbound" : "row row_inbound",
        bubbleClass: isOutbound
          ? "bubble bubble_outbound"
          : "bubble bubble_inbound"
      };
    });
  }

  // Puts the chosen template in the message box for the agent to edit before sending.
  handleTemplateSelect(event) {
    const template = this.templates.find((t) => t.value === event.detail.value);
    if (!template) {
      return;
    }
    this.draft = template.body;
    this.refs.input.value = template.body;
    this.refs.input.focus();
  }

  handleDraftChange(event) {
    this.draft = event.target.value;
  }

  handleKeyDown(event) {
    // isComposing: Enter confirms a Thai/IME word and must not send the message.
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault();
      this.handleSend();
    }
  }

  async handleSend() {
    const body = this.draft.trim();
    if (!body || this.isSending) {
      return;
    }
    this.isSending = true;
    try {
      const saved = await sendMessage({ recordId: this.recordId, body });
      this.draft = "";
      this.refs.input.value = "";
      this.rawMessages = [
        ...this.rawMessages.filter((m) => m.Id !== saved.Id),
        saved
      ];
      this.scrollPending = true;
      if (saved.Delivery_Status__c === "Failed") {
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Saved, but not delivered to LINE",
            message: saved.Delivery_Error__c || "",
            variant: "warning"
          })
        );
      }
    } catch (error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Message not sent",
          message: errorText(error),
          variant: "error"
        })
      );
    } finally {
      this.isSending = false;
    }
  }
}
