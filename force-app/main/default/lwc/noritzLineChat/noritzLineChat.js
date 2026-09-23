import { LightningElement, api } from "lwc";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import TIME_ZONE from "@salesforce/i18n/timeZone";
import getChat from "@salesforce/apex/NoritzLineChatController.getChat";
import sendMessage from "@salesforce/apex/NoritzLineChatController.sendMessage";

const CHANNEL = "/event/LINE_Chat_Refresh__e";
const FALLBACK_POLL_SECONDS = 3;
const URL_PATTERN = /https:\/\/\S+/;
const LINK_LABELS = {
  "Checkout Link": "Open checkout",
  "Payment Retry": "Update payment method"
};

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
  rawMessages = [];
  draft = "";
  isLoading = true;
  isSending = false;
  loadError;

  subscription;
  pollTimer;
  scrollPending = false;

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
      const data = await getChat({ accountId: this.recordId });
      const grew = data.messages.length !== this.rawMessages.length;
      this.customerName = data.customerName;
      this.lineUserId = data.lineUserId;
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
      if (event?.data?.payload?.Account_Id__c === this.recordId) {
        this.loadChat();
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
    return !this.isLoading && !this.loadError && !this.lineUserId;
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
        isOutbound && LINK_LABELS[m.Message_Type__c]
          ? body.match(URL_PATTERN)?.[0]
          : undefined;
      return {
        id: m.Id,
        text: linkUrl ? body.replace(linkUrl, "").trim() : body,
        time: m.Sent_At__c ? timeFormat.format(new Date(m.Sent_At__c)) : "",
        linkUrl,
        linkLabel: linkUrl ? LINK_LABELS[m.Message_Type__c] : undefined,
        failed: isOutbound && m.Delivery_Status__c === "Failed",
        rowClass: isOutbound ? "row row_outbound" : "row row_inbound",
        bubbleClass: isOutbound
          ? "bubble bubble_outbound"
          : "bubble bubble_inbound"
      };
    });
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

  handleOpenLink(event) {
    window.open(event.currentTarget.dataset.url, "_blank", "noopener");
  }

  async handleSend() {
    const body = this.draft.trim();
    if (!body || this.isSending) {
      return;
    }
    this.isSending = true;
    try {
      const saved = await sendMessage({ accountId: this.recordId, body });
      this.draft = "";
      this.refs.input.value = "";
      this.rawMessages = [
        ...this.rawMessages.filter((m) => m.Id !== saved.Id),
        saved
      ];
      this.scrollPending = true;
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
