import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import reset from "@salesforce/apex/DemoResetAction.reset";

const RELOAD_DELAY_MS = 1500;

export default class NoritzResetDemo extends LightningElement {
  @api recordId;
  isExecuting = false;

  @api async invoke() {
    if (this.isExecuting) {
      return;
    }
    this.isExecuting = true;
    try {
      await reset();
      this.toast(
        "Demo reset",
        "Somchai and Meng are back to the start. Reloading the page.",
        "success"
      );
      // Standard related lists (payments) aren't pushed live, so reload everything.
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => window.location.reload(), RELOAD_DELAY_MS);
    } catch (error) {
      this.isExecuting = false;
      this.toast(
        "Could not reset the demo",
        error?.body?.message || "Something went wrong.",
        "error"
      );
    }
  }

  toast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
