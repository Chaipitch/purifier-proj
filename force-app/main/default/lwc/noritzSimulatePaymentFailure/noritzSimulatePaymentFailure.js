import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import simulate from "@salesforce/apex/SimulatePaymentFailureAction.simulate";

export default class NoritzSimulatePaymentFailure extends LightningElement {
  @api recordId;
  isExecuting = false;

  @api async invoke() {
    if (this.isExecuting) {
      return;
    }
    this.isExecuting = true;
    try {
      await simulate({ recordId: this.recordId });
      // The recovery flow has already updated the contract in the same save; show it now. On a Lead
      // the retry message and history update live through the chat refresh event.
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.toast(
        "Payment failure simulated",
        "Card Expired (ERR-02). Recovery is running.",
        "warning"
      );
    } catch (error) {
      this.toast(
        "Could not simulate the failure",
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
