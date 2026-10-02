import { LightningElement, api } from "lwc";
import { subscribe, unsubscribe, onError } from "lightning/empApi";
import TIME_ZONE from "@salesforce/i18n/timeZone";
import getHistory from "@salesforce/apex/CustomerHistoryController.getHistory";

const CHANNEL = "/event/LINE_Chat_Refresh__e";
const FALLBACK_POLL_SECONDS = 5;

// Date-only fields come back as yyyy-MM-dd; format them in UTC so they don't shift a day.
const dateFormat = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  year: "numeric",
  timeZone: "UTC"
});
const dateTimeFormat = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
  timeZone: TIME_ZONE
});
const money = new Intl.NumberFormat("en-GB", {
  style: "currency",
  currency: "THB",
  maximumFractionDigits: 0
});

const CONTRACT_BADGE = {
  Active: "badge badge_good",
  "Payment Failed": "badge badge_bad"
};

function formatDate(value) {
  return value ? dateFormat.format(new Date(value)) : "—";
}

export default class NoritzCustomerHistory extends LightningElement {
  @api recordId;

  customerId;
  rawProducts = [];
  rawContracts = [];
  rawPayments = [];
  isLoading = true;
  loadError;
  subscription;
  pollTimer;

  connectedCallback() {
    this.load();
    onError(() => this.startPolling());
    subscribe(CHANNEL, -1, (event) => {
      const changedId = event?.data?.payload?.Account_Id__c;
      if (changedId && changedId === this.customerId) {
        this.load();
      }
    })
      .then((sub) => {
        this.subscription = sub;
      })
      .catch(() => this.startPolling());
  }

  disconnectedCallback() {
    if (this.subscription) {
      unsubscribe(this.subscription);
      this.subscription = undefined;
    }
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = undefined;
    }
  }

  startPolling() {
    if (!this.pollTimer) {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      this.pollTimer = setInterval(
        () => this.load(),
        FALLBACK_POLL_SECONDS * 1000
      );
    }
  }

  async load() {
    try {
      const data = await getHistory({ recordId: this.recordId });
      this.customerId = data.customerId;
      this.rawProducts = data.products;
      this.rawContracts = data.contracts;
      this.rawPayments = data.payments;
      this.loadError = undefined;
    } catch (error) {
      this.loadError = error?.body?.message || "Could not load the history.";
    } finally {
      this.isLoading = false;
    }
  }

  get products() {
    return this.rawProducts.map((a) => ({
      id: a.Id,
      url: `/lightning/r/Assets__c/${a.Id}/view`,
      name: a.Name,
      product: a.Product__r?.Name,
      serial: a.Serial_Number__c,
      nextFilter: formatDate(a.Next_Filter_Replacement__c),
      filterStatus: a.Filter_Status_Icon__c
    }));
  }

  get contracts() {
    return this.rawContracts.map((c) => ({
      id: c.Id,
      url: `/lightning/r/Contracts__c/${c.Id}/view`,
      number: c.Name,
      plan: c.Subscription_Plan__c || "No plan",
      status: c.Status__c,
      badgeClass: CONTRACT_BADGE[c.Status__c] || "badge",
      nextBilling: formatDate(c.Next_Billing_Date__c)
    }));
  }

  get payments() {
    return this.rawPayments.map((p) => {
      const failed = p.Status__c === "Failed";
      return {
        id: p.Id,
        when: dateTimeFormat.format(new Date(p.CreatedDate)),
        amount: p.Amount__c == null ? "—" : money.format(p.Amount__c),
        status: p.Status__c,
        reason: failed ? p.Failure_Reason__c : undefined,
        contract: p.Contract__r?.Name,
        rowClass: failed ? "payment payment_failed" : "payment"
      };
    });
  }

  get hasProducts() {
    return this.rawProducts.length > 0;
  }

  get hasContracts() {
    return this.rawContracts.length > 0;
  }

  get hasPayments() {
    return this.rawPayments.length > 0;
  }
}
