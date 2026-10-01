import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import sendNow from "@salesforce/apex/SendFilterReminderAction.sendNow";

const VARIANT = { Sent: "success", "Not linked": "warning", Failed: "warning" };

export default class NoritzSendFilterReminder extends LightningElement {
  @api recordId;
  isExecuting = false;

  @api async invoke() {
    if (this.isExecuting) {
      return;
    }
    this.isExecuting = true;
    try {
      const result = await sendNow({ assetId: this.recordId });
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.toast(
        result.status === "Sent"
          ? "Filter reminder sent"
          : "Filter reminder not delivered",
        result.message,
        VARIANT[result.status] || "error"
      );
    } catch (error) {
      this.toast(
        "Filter reminder not sent",
        error?.body?.message || "Something went wrong.",
        "error"
      );
    } finally {
      this.isExecuting = false;
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
