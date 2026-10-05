// Puts the whole demo back to its pre-demo state: Somchai and every LINE customer and lead.
// Safe to run repeatedly. The "Reset Demo" button resets only the record it's pressed on; both
// use DemoResetAction.
// sf apex run --file scripts/apex/reset_demo.apex --target-org noritz
DemoResetAction.reset();
