import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import send from "@salesforce/apex/SendCheckoutLinkAction.send";

const VARIANT = { Sent: "success", "Not linked": "warning", Failed: "warning" };

export default class NoritzSendCheckoutLink extends LightningElement {
  @api recordId;
  isExecuting = false;

  @api async invoke() {
    if (this.isExecuting) {
      return;
    }
    this.isExecuting = true;
    try {
      const result = await send({ recordId: this.recordId });
      this.toast(
        result.status === "Sent"
          ? "Checkout link sent"
          : "Checkout link not delivered",
        result.message,
        VARIANT[result.status] || "error"
      );
    } catch (error) {
      this.toast(
        "Checkout link not sent",
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
