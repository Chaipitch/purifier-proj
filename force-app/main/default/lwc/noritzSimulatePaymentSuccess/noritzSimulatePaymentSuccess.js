import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { notifyRecordUpdateAvailable } from "lightning/uiRecordApi";
import simulate from "@salesforce/apex/SimulatePaymentSuccessAction.simulate";

export default class NoritzSimulatePaymentSuccess extends NavigationMixin(
  LightningElement
) {
  @api recordId;
  isExecuting = false;

  @api async invoke() {
    if (this.isExecuting) {
      return;
    }
    this.isExecuting = true;
    try {
      // On a Lead the first payment converts it, and we get the new customer's Account back.
      const accountId = await simulate({ recordId: this.recordId });
      if (accountId) {
        this.toast(
          "Payment received: lead converted",
          "Opening the new customer. Their LINE chat moved with them.",
          "success"
        );
        this[NavigationMixin.Navigate]({
          type: "standard__recordPage",
          attributes: { recordId: accountId, actionName: "view" }
        });
        return;
      }
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
