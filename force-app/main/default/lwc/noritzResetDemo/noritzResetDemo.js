import { LightningElement, api } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import resetFrom from "@salesforce/apex/DemoResetAction.resetFrom";

const RELOAD_DELAY_MS = 1500;

export default class NoritzResetDemo extends NavigationMixin(LightningElement) {
  @api recordId;
  isExecuting = false;

  @api async invoke() {
    if (this.isExecuting) {
      return;
    }
    this.isExecuting = true;
    try {
      // Set when this page's record was a converted customer the reset removed: open the
      // fresh lead that replaces it instead of reloading a deleted record.
      const replacement = await resetFrom({ recordId: this.recordId });
      this.toast(
        "Demo reset",
        replacement
          ? "This customer is back to the start as a fresh lead. Opening it."
          : "This customer is back to the start. Reloading the page.",
        "success"
      );
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      setTimeout(() => {
        if (replacement) {
          this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: { recordId: replacement, actionName: "view" }
          });
        } else {
          // Standard related lists (payments) aren't pushed live, so reload everything.
          window.location.reload();
        }
      }, RELOAD_DELAY_MS);
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
