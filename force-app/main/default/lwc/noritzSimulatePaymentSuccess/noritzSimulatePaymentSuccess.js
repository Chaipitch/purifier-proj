import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import simulate from "@salesforce/apex/SimulatePaymentSuccessAction.simulate";

export default class NoritzSimulatePaymentSuccess extends LightningElement {
  @api recordId;
  isExecuting = false;

  @api async invoke() {
    if (this.isExecuting) {
      return;
    }
    this.isExecuting = true;
    try {
      await simulate({ contractId: this.recordId });
      // Notify UI of the update so standard components refresh
      notifyRecordUpdateAvailable([{ recordId: this.recordId }]);
      this.toast(
        "Payment success simulated",
        "Payment processed successfully.",
        "success"
      );
    } catch (error) {
      this.toast(
        "Could not simulate the payment",
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
