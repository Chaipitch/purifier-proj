# NORITZ Demo — Implementation Tracker

Target org: `noritz` (Developer Edition, `orgfarm-28f7eccd9f-dev-ed`)
Spec: [CLAUDE.md](CLAUDE.md) · Wireframe: [docs/wireframe.png](docs/wireframe.png) · Last updated: 2026-10-30

**Round 2 (2026-10-01):** LINE leads, conversion on first payment, chat templates, filter reminders, customer history, chat on Lead/Case. See [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md), [docs/CHANGES.md](docs/CHANGES.md), [docs/HANDOFF.md](docs/HANDOFF.md) and [docs/TESTING.md](docs/TESTING.md). Where this file and docs/ disagree, docs/ is newer.

**Legend:** `[x]` done · `[ ]` to do · ⏸ deferred

---

## Status at a glance

| Area                                                         | Status     | Notes                                                               |
| ------------------------------------------------------------ | ---------- | ------------------------------------------------------------------- |
| Org verification                                             | ✅ Done    | All §1 fields exist; Person Accounts on                             |
| Contract status model                                        | ✅ Done    | Standard `Status`; `Payment Failed` moved to Activated              |
| LINE chat widget (`noritzLineChat`)                          | ✅ Done    | On the Account page, left column                                    |
| Real LINE OA connection (send + receive)                     | ✅ Done    | Tested both ways with a real phone                                  |
| Live refresh                                                 | ✅ Done    | Platform event `LINE_Chat_Refresh__e` + empApi                      |
| Scenario 1 — Quick Signup                                    | ✅ Done    | One-click button on the Contract                                    |
| Scenario 2 — Payment Failure & Auto Recovery                 | ✅ Done    | Record-triggered Flow + one-click button                            |
| Reset (button + script)                                      | ✅ Done    | **Reset Demo** on the Contract page; `scripts/apex/reset_demo.apex` |
| Apex tests                                                   | ✅ 54 pass | Every new class covered 90%+                                        |
| Round 2: first LINE chat → Lead                              | ✅ Done    | Account wins if the LINE id is already on one                       |
| Round 2: Lead → Person Account on first payment              | ✅ Done    | Simulate Payment Success on the Lead                                |
| Round 2: chat on Lead / Account / Case + templates           | ✅ Done    | Templates in custom metadata `LINE_Chat_Template__mdt`              |
| Round 2: filter reminder (invocable, daily flow, button)     | ✅ Done    | Daily flow not yet seen live                                        |
| Round 2: Customer History card                               | ✅ Done    | Failed payments bold red, live refresh                              |
| Stripe webhook endpoint (Task 10)                            | ⏸ Deferred | Second way to trigger Scenario 2, from Postman                      |
| Header badge, payment timeline, asset card LWCs              | ⏸ Deferred | User chose the chat widget only; standard components cover the rest |
| Console app "NORITZ Subscription Console" (Task 3)           | ⏸ Deferred | Demo runs in the existing **Service Console** app                   |
| Chat position on the page                                    | ⏸ Deferred | Below the fold at 1440×900; user chose not to move it               |
| Rehearsal + backup screen recording (Task 11)                | [ ] To do  | Use the run-book below                                              |
| CLAUDE.md §2.1 / §2.5 still mention `Subscription_Status__c` | [ ] To do  | Update so a later session doesn't create the field                  |

---

## Demo run-book

### Before the audience arrives

1. **Reset the demo** (safe to run any number of times; touches Somchai and customers with a LINE User ID): click **Reset Demo** on any Contract page. The page reloads itself. From a terminal instead:
   ```bash
   sf apex run --file scripts/apex/reset_demo.apex --target-org noritz
   ```
2. **Open the console:** App Launcher → **Service Console** → Accounts → **Somchai Sukhumvit**. If anything was deployed today, reload the page **twice** (the first load can still run the old component).
3. **Open his contract as a second tab:** on Somchai's page, right column → **Contracts** → **00000101**.
4. **Phone:** open LINE on the NORITZ OA chat. Optionally clear the chat history on the phone so it matches the reset Salesforce chat.
5. **Pre-flight check on Somchai's tab:**
   - Highlights: Status **Active**, Subscription Plan **Premium (1,500 THB)**
   - Chat: 3 messages, ending with "เอา Premium ครับ"; no yellow "hasn't linked a LINE account" banner
   - Contract tab: Status **🟢Active**

### Beat 1 — One screen for the customer

On Somchai's tab: highlights (Status, plan, next filter date), the Path, and the right column (Assets with Filter Health, Contracts, Payment History with two successful payments). Scroll the left column to the **LINE Chat** and show the conversation history.

### Beat 2 — Contract and asset

Switch to the Contract tab: Path **Pending Payment → Active → Payment Failed**, currently Active. Show the asset in the Assets list on Somchai's page (Filter Health).

### Beat 3 — Scenario 1: Quick Signup (checkout link over LINE)

1. On the Contract tab, click **Send Stripe Checkout Link**.
2. Green toast: "Checkout link sent — The customer has it on LINE."
3. The phone receives the English message with `https://checkout.stripe.com/demo/sub_demo_12345`.
4. Switch to Somchai's tab: the chat already shows the green bubble with an **Open checkout** button.

**Optional live chat moment:** type a reply on the phone → it appears in the widget within ~2 s. Type an answer in the widget and press Enter → it arrives on the phone.

### Beat 4 — Scenario 2: Payment Failure & Auto Recovery (the highlight)

1. On the Contract tab, click **Simulate Payment Failure**.
2. Orange toast: "Payment failure simulated — Card Expired (ERR-02). Recovery is running."
3. Within ~2 s, no refresh: contract Status flips **🟢Active → 🔴Payment Failed**.
4. The phone receives the English retry message with the `.../demo/sub_demo_12345/update-payment` link.
5. Switch to Somchai's tab: Status **Payment Suspended** in the highlights and the Path, and the chat shows the retry message with an **Update payment method** button.
6. Optional: open Setup → Flows → **Payment Failure Recovery** to show the automation.

### Beat 5 — Reset for the next run

Click **Reset Demo** on the Contract tab. The page reloads after the green toast.

### If something goes wrong on stage

| Symptom                                               | What to do                                                                                                                          |
| ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Chat doesn't update                                   | Reload the page. If it keeps happening, App Builder → chat component → set **Polling interval** to 2.                               |
| "Not delivered" under an outbound bubble              | Hover it to see LINE's error. Usually the channel access token (Setup → Named Credentials → External Credentials → LINE Messaging). |
| Phone reply never appears                             | LINE Developers → Messaging API: webhook URL set, **Use webhook** on; OA Manager: auto-response off.                                |
| Page shows old behaviour after a deploy               | Reload twice.                                                                                                                       |
| Contract won't change status                          | Run the reset; it puts the contract back to Active.                                                                                 |
| Payment History related list doesn't show the failure | Refresh that list (its refresh icon) or reload; standard related lists aren't pushed live.                                          |

---

## What was built

### LINE chat widget

- [x] `LINE_Message__c`: `Account__c`, `Direction__c`, `Message_Body__c`, `Sent_At__c`, `Message_Type__c`, plus `LINE_User_ID__c`, `LINE_Message_ID__c` (unique, stops duplicate webhook deliveries), `Delivery_Status__c`, `Delivery_Error__c`. `Contract__c` from the spec is not used.
- [x] `noritzLineChat` LWC on `Account_Record_Page`, left column: inbound left / outbound right in LINE green, en-GB timestamps, auto-scroll, Enter to send (not while a Thai word is being composed), link buttons for Checkout Link and Payment Retry, "Not delivered" with the LINE error on hover, banner when the customer has no LINE id.
- [x] `NoritzLineChatController` (load + send), permission set `LINE_Chat_User`.
- [x] Live refresh: `LineMessageTrigger` publishes `LINE_Chat_Refresh__e` (after commit) on message insert/delete; the widget subscribes via empApi, reloads, and asks the page to re-read the Account so the standard highlights and Path update too. Falls back to 3 s polling if the subscription fails.

### Real LINE OA connection

- [x] Outbound: External Credential `LINE_Messaging` + Named Credential `LINE_Messaging_API`; `LineMessagingService` pushes first, then saves the message with its delivery result.
- [x] Inbound: `LineWebhookHandler` on Site `line_webhook`, verifies `X-Line-Signature`, skips redeliveries, matches the customer by LINE id, saves unknown senders without an account.
- [x] Guest user: permission set `LINE_Webhook_Guest` (webhook class, message create, custom setting, refresh event). No Account access.
- [x] Token and secret were entered in Setup by the user; nothing secret is in source.
- [x] Somchai's `LINE_User_ID__c` is linked to the user's test LINE account.
- Webhook URL: `https://orgfarm-28f7eccd9f-dev-ed.develop.my.salesforce-sites.com/line/services/apexrest/line/webhook`

### New LINE friends become Prospect accounts (2026-09-24)

- [x] Follow event (someone adds the OA) → Prospect Person Account named after their LINE display name, with their LINE id; chat line "[Added the OA as a friend]"
- [x] A message from an unknown LINE user does the same (covers people who followed before this existed)
- [x] Earlier unattached messages from that LINE id are attached to the new account
- [x] Profile lookup fails → account is still created as "LINE friend ····1234" (last 4 characters of their LINE id)
- [x] Redelivered events create no second account or message
- [x] Guest permission set now includes the LINE credential (for the profile lookup only)
- [x] Apex tests: 25 passing
- [x] If a lookup failed earlier, the next message retries it and renames the placeholder account
- [x] Live test (2026-09-24): a second LINE account (Meng) added the OA → Prospect account created, renamed to "Meng" on the next message

### Switching to a different LINE OA

1. New channel access token → Setup → Named Credentials → External Credentials → **LINE Messaging** → principal **LINE_Bot** → edit parameter `token` (keep the name lowercase).
2. New channel secret → Setup → Custom Settings → **LINE Settings** → Manage → edit org default.
3. New channel in LINE Developers: same webhook URL, Verify, **Use webhook** on; OA Manager: auto-response off. Turn the webhook off on the old channel.
4. LINE user ids differ per provider. When your phone adds the new OA, it now becomes a **new Prospect account**. To keep demoing as Somchai: copy that account's LINE User ID into Somchai's record, delete the new Prospect account, then run the reset script.
5. Don't redeploy `externalCredentials/` to do this.

### Scenario 1 — Quick Signup

- [x] "Send Stripe Checkout Link" on the Contract (first action on `Contract Layout`): headless LWC `noritzSendCheckoutLink` → `SendCheckoutLinkAction.send` → push + save as Checkout Link → toast.
- [x] English message ("Hi <first name>," then "Thank you for choosing NORITZ…") with the plan name and mock link `https://checkout.stripe.com/demo/<Stripe_Sub_ID__c>`.

### Scenario 2 — Payment Failure & Auto Recovery

- [x] Contract status values: Pending Payment (Draft) → Active (Activated) → Payment Failed (Activated).
- [x] Record-triggered Flow `Payment_Failure_Recovery` on `Payment_History__c` (after insert, `Status__c = Failed`): Contract → Payment Failed, Account → Payment Suspended, publish refresh, call `SendPaymentRetryAction`.
- [x] `SendPaymentRetryAction` queues a job that pushes the English retry message ("Hi <first name>," then the spec's "Payment failed for your monthly subscription…") (`.../demo/<sub>/update-payment`) and saves it as Payment Retry.
- [x] "Simulate Payment Failure" on the Contract: headless LWC `noritzSimulatePaymentFailure` → `SimulatePaymentFailureAction.simulate` inserts a failed payment (plan price, `Card Expired (ERR-02)`), then refreshes the contract page.

### Reset

- [x] `DemoResetAction.reset()`: deletes Somchai's payments and chat; contract → Active, Premium, `sub_demo_12345`, next billing 1st of this month; account → Active; 2 successful payments; 3 chat messages. Every other customer with a LINE User ID: payments and chat deleted except the "[Added the OA as a friend]" line, Payment Failed contracts → Active, account → Active if it has an Active contract, otherwise Prospect. Customers without a LINE User ID are untouched.
- [x] **Reset Demo** button on the Contract page (third action; headless LWC `noritzResetDemo`), toast then page reload, for the non-technical BA. `scripts/apex/reset_demo.apex` now just calls `DemoResetAction.reset()`. Tests: `DemoResetActionTest` (3).

---

## Round 3 — full business flow, step by step (planned 2026-10-30)

Source documents: *Subscription Business: Operational Overview*, the Krungsri *Merchant Acquiring Services* proposal (2026-05-05) and the Toukei *swifT* introduction. Krungsri is the payment gateway; swifT (Toukei Thailand) is the core accounting system. Overview diagram: the "NORITZ Subscription Flow" artifact.

Steps are planned one at a time. Each step lists what the customer sees, the build tasks and its estimate.

### Step 1 — Customer adds the LINE OA ✅ already built

- [x] LINE `follow` event creates a Lead named after the LINE display name, with `LINE_User_ID__c` and Lead Source = LINE (`LineWebhookHandler.createLeads`).
- [x] A LINE user who is already a customer gets no new Lead; their messages go to the Account.
- [x] Every message is saved as `LINE_Message__c` and shown in the chat widget on the Lead page.

### Step 2 — Sign-up form inside LINE (LIFF) [ ] ~2 days

**Customer view:** agent clicks **Send sign-up form** on the Lead → customer gets a LINE message with a "Complete your sign-up" button → the form opens inside LINE (LIFF, Full size) → on submit the panel closes and a "Thanks, we've received your details" bubble appears → Lead Status becomes **Form Submitted** and the agent gets a bell notification.

**Identity:** the form sends the LIFF ID token to Apex, which verifies it with LINE (`https://api.line.me/oauth2/v2.1/verify`) to get the LINE user id, then finds the open Lead by `LINE_User_ID__c`. No per-Lead link or token field.

**Needed from the user (LINE Developers):** a LINE Login channel under the **same provider** as the Messaging API channel (otherwise the user ids differ); a LIFF app in it (size Full, scopes `profile` + `openid`, endpoint = the form page URL we provide); then send us the LIFF ID and the Login channel ID.

| Field                         | Required | Lead field                                                  |
| ----------------------------- | -------- | ----------------------------------------------------------- |
| First / last name             | yes      | `FirstName`, `LastName`                                     |
| Mobile                        | yes      | `MobilePhone`                                               |
| Email                         | no       | `Email`                                                     |
| House no. and street          | yes      | `Street`                                                    |
| Subdistrict                   | yes      | new `Subdistrict__c`                                        |
| District                      | yes      | `City`                                                      |
| Province                      | yes      | `State`                                                     |
| Postcode                      | yes      | `PostalCode`                                                |
| Where in the home             | yes      | new `Installation_Location__c` (Kitchen, Living room, Other) |
| Preferred installation date   | yes      | new `Preferred_Install_Date__c`                             |
| Plan                          | yes      | existing `Subscription_Plan__c`                             |
| Tax ID (13 digits)            | **no**   | new `Tax_ID__c`, digit check only when filled               |
| Billing address               | no       | "Same as installation" box, or new billing address fields   |
| PDPA consent                  | yes      | new `PDPA_Consent__c` + `PDPA_Consent_Date__c`              |

- [ ] 2.1 New Lead fields, Lead Status value "Form Submitted", Lead layout (0.25 d)
- [ ] 2.2 Form page on the existing Salesforce Site with the LIFF SDK, Thai/English labels, phone-first layout (0.75 d)
- [ ] 2.3 Guest-safe Apex: verify the LIFF ID token, update the Lead, post the thank-you message; tests (0.5 d)
- [ ] 2.4 **Send sign-up form** button on the Lead (LINE message with the LIFF link) (0.25 d)
- [ ] 2.5 Reset puts the demo Lead back to "not yet submitted" (0.1 d)

Decision: the link is sent by the agent's button, not automatically on follow, so the presenter controls the timing.

### Step 3 — First payment through Krungsri (mock) [ ] ~2.5 days

**Customer view:** once the Lead is Form Submitted, the agent clicks **Send payment link** (today's Send Checkout Link, renamed) → the customer gets a LINE message with a "Pay now" button → a mock payment page opens with the plan and amount, a choice of **Card** or **PromptPay QR**, and a "Save this card for monthly payments" box → the customer taps Pay → the page posts the result to Salesforce, as Krungsri's "Post URL" would → on success the Lead converts and LINE says "Payment received, we'll confirm your installation date"; on failure the Lead stays and LINE sends "Payment didn't go through" with the link again.

**What changes in existing code**

- `LeadConversionService.convertOnFirstPayment`: also copies the form data (address, subdistrict, tax ID, installation location, preferred date, PDPA consent) to the Person Account and the contract; the new contract ends in **Pending Installation**, not Active (Active now comes from Step 4, installation complete); the customer ends in **Awaiting Installation**, not Active. The first payment is the first month's fee only (no initial fee).
- `Payment_Success_Recovery` flow: a first payment must not set the contract to Active; only payments on an installed contract do.
- `SendCheckoutLinkAction`: mock Krungsri URL instead of `checkout.stripe.com/demo/`; only allowed when the Lead is Form Submitted.
- `Stripe_Sub_ID__c` (Lead and `Contracts__c`) is replaced by a new `Payment_Reference__c`. Salesforce cannot rename an API name, so the new field is added, data copied, and every reference switched (4 classes, 2 quick actions, tests, reset, CLAUDE.md) before the old field is retired.
- **Simulate Payment Success** stays as the on-stage backup.

- [ ] 3.1 Fields: `Payment_Reference__c` (Lead, `Contracts__c`); on `Contracts__c` `Payment_Method__c` (Card, Saved Card, PromptPay QR), `Card_Token_Ref__c` and `Card_Last4__c` (mock values only, never card data), `Billing_Frequency__c` (Monthly); on `Payment_History__c` `Payment_Method__c` and `Gateway_Transaction_ID__c`; `Contracts__c.Status__c` value **Pending Installation**; `Account.Customer_Status__c` value **Awaiting Installation** (0.5 d)
- [ ] 3.2 Mock payment page on the Salesforce Site, clearly labelled as a demo, no bank branding, `/demo/` in the URL (0.75 d)
- [ ] 3.3 Payment result endpoint `/services/apexrest/krungsri/payment/demo/*` (replaces the deferred Stripe webhook, Task 10): resolve by `Payment_Reference__c`, JSON error if not found, success → conversion, failure → retry message; tests for success, failure and not found. No signature check (production needs one) (0.5 d)
- [ ] 3.4 Conversion and flow changes above, with tests (0.5 d)
- [ ] 3.5 LINE messages for success and failure, rename Stripe references, reset script (0.25 d)

**Decisions (2026-10-30):** clickable mock payment page on the phone; no initial fee, the first payment is the first month (Standard 900 / Premium 1,500 THB); new customer status **Awaiting Installation** between payment and installation.

### Step 4 — Shipping and installation [ ] ~3 days

**Customer view:** the payment converts the Lead → an **Installation** work order is created automatically with the customer's preferred date → the agent picks the installation partner and confirms the date → LINE: "Your installation is booked for 12 Nov 2026, 10:00, with Siam Water Service" → the unit ships to the partner → the partner installs it and reports back (photos, serial number, customer confirmation) → the agent clicks **Complete Installation** → within ~2 s, no refresh: asset **In Use**, contract **Active**, customer **Active**, filter date set, and LINE: "Your NORITZ purifier is installed. Next billing: 1 Dec 2026".

**Objects**

- **Installation partner:** a Business Account with record type **Installation Partner** (Person Accounts stay on for customers). Fields: contact, service area, tax ID (later for partner payments).
- **Work order:** standard `WorkOrder` if it is enabled in the org (verify first), otherwise a custom `Work_Order__c`. New fields: `Work_Type__c` (Installation, Filter, Repair, Removal — later steps reuse it), `Partner__c`, `Contract__c`, `Asset__c`, `Scheduled_Date__c`, `Shipment_Status__c` (Not Shipped, Shipped to Partner, Received by Partner), `Serial_Number__c`, `Customer_Confirmed__c`, `Completed_Date__c`, `Partner_Feedback__c`. Photos are Files on the work order.
- **Asset status:** add **In Warehouse** and **At Partner**; relabel **Installed** as **In Use**; retire **Purchased** later (the company keeps ownership, nothing is sold). `Assets__c` gets a `Contract__c` lookup.

- [ ] 4.1 Partner record type, work order object and fields, asset status values, `Assets__c.Contract__c`, layouts (0.5 d)
- [ ] 4.2 On conversion: create the Installation work order (preferred date from the form) and an `Assets__c` record (In Warehouse, no serial yet) linked to the contract (0.5 d)
- [ ] 4.3 **Book Installation** action: choose partner and date → LINE booking message to the customer (0.25 d)
- [ ] 4.4 Shipment status on the work order (set by hand or a mock "swifT shipped" button for now; the real swifT file comes in a later step) → asset At Partner (0.25 d)
- [ ] 4.5 **Complete Installation** action (LWC): serial number, photo upload, customer confirmed tick box, feedback (0.75 d)
- [ ] 4.6 Installation-complete automation: asset In Use with serial and install date, `Next_Filter_Replacement__c` = install date + filter interval, contract Active with `Next_Billing_Date__c` = 1st of the month after installation, customer Active, LINE message, live refresh. Filter interval read from new custom metadata `Subscription_Setting__mdt.Filter_Interval_Months__c` (default 6) (0.5 d)
- [ ] 4.7 Partner demo data, reset (Somchai stays fully installed so Scenario 2 still works), tests (0.25 d)

**Decisions (2026-10-30):** the agent records the completion report on the partner's behalf; monthly billing starts on the **1st of the month after installation**; filter interval **6 months**, held in custom metadata so it can change without a deploy (demo data keeps "due in 14 days").

### Step 5 — Monthly billing, failed payments and renewal [ ] ~2.75 days

**Customer view:** on the 1st of each month Krungsri charges the saved card → the result is posted to Salesforce → **paid:** LINE "We've received 1,500 THB for your December subscription. Thank you!" → **failed:** the existing recovery runs (contract Payment Failed, customer Payment Suspended, bold red row, retry message) → the customer taps the retry link, which opens the mock payment page in **update card** mode → the new card is saved and charged at once → contract and customer back to Active, LINE "Payment received, your service continues".

**Approach (recommended):** Krungsri runs the recurring schedule in its own portal; Salesforce only records the results it posts back. For the demo, a mock **Krungsri billing run** plays Krungsri's part. Both the run and the existing Simulate buttons send their result through the Step 3 payment endpoint, so every path behaves the same.

- [ ] 5.1 Contract fields: `Recurring_Start_Date__c`, `Number_of_Payments__c`, `Last_Payment_Date__c`, demo-only `Fail_Next_Charge__c` tick box (0.25 d)
- [ ] 5.2 Mock billing run: a button (and an optional daily scheduled job) that charges every Active contract whose `Next_Billing_Date__c` is today or earlier, using its saved card; success unless `Fail_Next_Charge__c` is ticked (0.5 d)
- [ ] 5.3 Paid: `Payment_History__c` row with method and transaction id, `Next_Billing_Date__c` moves to the next 1st, LINE "payment received" message (0.25 d)
- [ ] 5.4 Failed: reuse `Payment_Failure_Recovery`; retry link opens the mock payment page in update-card mode; new card token saved and charged immediately → `Payment_Success_Recovery` (0.5 d)
- [ ] 5.5 Rewire **Simulate Payment Success / Failure** through the payment endpoint; reset; tests (0.5 d)
- [ ] 5.6 Renewal choice: a daily flow sends a LINE message `Renewal_Notice_Days__c` (custom metadata, default 30) before `Contract_End_Date__c`, with three quick-reply buttons: **Renew 12 months**, **Continue monthly**, **End service**. The LINE webhook learns `postback` events (shared with Step 6 booking). Renew → end date + 12 months, `Number_of_Payments__c` + 12; Continue monthly → `Renewal_Type__c` = Month-to-month; End service → contract **Termination Requested** → Step 7. Agent gets a bell notification. No answer: a second reminder 7 days before the end, then the contract continues monthly so service never stops (assumption, confirm with the client). New fields `Renewal_Type__c`, `Renewal_Notice_Sent__c` (0.75 d)

**Decisions (2026-10-30):** Krungsri runs the recurring schedule and Salesforce only records the results; the sign-up payment is month 1 of 12, no proration; before the term ends the subscriber gets a LINE notification and chooses to renew, continue monthly or end.

### Step 6 — Filter care and repairs [ ] ~2.5 days

**Customer view, filter:** the existing filter reminder now ends with three time-slot buttons ("Tue 18 Nov morning", …) → the customer taps one → a **Filter** work order is created for that slot → the agent assigns a partner (Step 4 **Book** action) → after the visit the agent clicks **Complete Visit** → next filter date = visit date + 6 months, LINE "Your filter has been replaced. Next replacement: May 2027".

**Customer view, repair:** the customer reports a problem in LINE or by phone → the agent opens a Case (already built) → **Create Repair Visit** on the Case → **Repair** work order, asset **Under Repair** → after the visit the agent records the outcome: **Repaired**, or **Unit swapped** (new serial number: old asset → Returned and on to Step 7 inspection, new asset → In Use on the same contract) → Case closes, LINE "Your purifier has been repaired".

- [ ] 6.1 Filter reminder with time-slot quick replies (postback, shared with 5.6) → Filter work order; uses the existing `Filter_Booking` chat template (0.5 d)
- [ ] 6.2 Reuse **Book** and **Complete Visit** for Filter visits; completion resets the filter date from the metadata interval and sends the LINE message (0.5 d)
- [ ] 6.3 Case gets an `Asset__c` lookup; **Create Repair Visit** action → Repair work order, asset Under Repair (0.25 d)
- [ ] 6.4 Repair outcome: Repaired or Unit swapped (new asset record, old one Returned, contract relinked); close the Case; LINE message (0.75 d)
- [ ] 6.5 Customer History card lists visits; reset; tests (0.5 d)

**Decisions (2026-10-30):** the customer picks a filter slot in LINE; filter visits and repairs are always free (no charge path needed); a swapped unit keeps the same contract and end date.

### Step 7 — Cancellation, removal and return [ ] ~2.25 days

**Customer view:** the customer taps **End service** on the renewal message (Step 5.6), or asks to cancel early in LINE or by phone and the agent clicks **Request Termination** → contract **Termination Requested** → if before the end date, the early-termination fee is worked out and charged to the saved card → LINE summary: last day of service, fee (if any), and time-slot buttons for the removal visit → **Removal** work order, partner booked → after the visit the agent clicks **Complete Visit** → asset **Returned**, contract **Terminated**, monthly charges stop, customer **Former Customer**, LINE "Your purifier has been collected. Thank you for using NORITZ."

**Back at the warehouse:** every returned unit (from removal, or swapped out in Step 6) gets **Record Inspection** → **Ready for Reuse**, **Under Repair** or **Disposed**. New installations (Step 4.2) take a Ready for Reuse unit before a new one.

- [ ] 7.1 Fields and values: contract `Termination_Requested_Date__c`, `Termination_Reason__c`, `Early_Termination_Fee__c`, `Service_End_Date__c`; contract statuses Termination Requested and Terminated; customer status Former Customer; asset statuses Returned, Inspection, Ready for Reuse, Disposed; `Inspection_Result__c`, `Inspection_Notes__c` (0.25 d)
- [ ] 7.2 **Request Termination** action, sharing one path with the 5.6 End service button; fee rule from custom metadata; LINE summary with removal slot buttons (postback, as 6.1) (0.5 d)
- [ ] 7.3 Fee charged through the payment endpoint with the saved card (mock) (0.25 d)
- [ ] 7.4 Removal visit: Book and Complete Visit → asset Returned, contract Terminated, billing run skips the contract, customer Former Customer, LINE goodbye (0.5 d)
- [ ] 7.5 **Record Inspection** action on the asset; Step 4.2 reuses Ready for Reuse units first (0.5 d)
- [ ] 7.6 Reset, tests (0.25 d)

**Decisions (2026-10-30):** the early-termination fee rule lives in custom metadata (`Subscription_Setting__mdt`: rule None / Fixed / Percent of remaining months, plus amount and percent), so the client can change it without a deploy; customer status after cancellation is **Former Customer**; whether new installations reuse inspected units first is also a metadata switch (`Reuse_Returned_Units_First__c`).

### Step 8 — Hand-off to swifT [ ] ~3 days · draft, awaiting decisions

swifT (Toukei Thailand) keeps accounting, tax and fixed assets; it imports and exports CSV files. Salesforce sends what swifT needs and stores the numbers swifT sends back, linked by contract number, Salesforce asset id and serial number.

**Salesforce → swifT (export files)**

| File            | When a row is added                    | Main columns                                                                |
| --------------- | -------------------------------------- | --------------------------------------------------------------------------- |
| Sales orders    | Lead converted (Step 3)                | contract no., customer, tax ID, address, goods code, monthly price          |
| Payments        | every successful payment (Steps 3, 5, 7) | contract no., amount, date, method, Krungsri transaction id, charge type (Service = monthly fee, VAT due on payment) |
| Fixed assets    | installation complete (Step 4)         | Salesforce asset id, serial no., goods code, acquisition value, in-use date, location |
| Partner payments | visit completed (Steps 4, 6, 7)       | partner, tax ID, visit type, standard fee, withholding tax 3%               |
| Asset changes   | unit returned or disposed (Steps 6, 7) | Salesforce asset id, serial no., new status, date                           |

**swifT → Salesforce (import file):** shipment status (replaces the manual button in 4.4), tax invoice and receipt numbers per payment, fixed asset number per asset.

- [ ] 8.1 Fields and metadata: goods code per plan, standard partner fee per visit type, WHT rate 3%, `swifT_Customer_Code__c`, `swifT_Order_No__c`, `swifT_Receipt_No__c`, `swifT_Tax_Invoice_No__c`, `Fixed_Asset_Number__c`, `Exported_To_swifT__c` on each exported record (0.5 d)
- [ ] 8.2 Export engine: one Apex class that writes each file from a column layout held in custom metadata (so it can match Toukei's format without code), marks rows as exported so nothing is sent twice; **Export to swifT** button plus an optional daily job; files saved on a **swifT Exchange** record (0.75 d)
- [ ] 8.3 The five exports above (0.5 d)
- [ ] 8.4 Import: upload swifT's reply CSV → shipment status, invoice and receipt numbers, fixed asset numbers written back; a **Simulate swifT reply** button for the demo (0.75 d)
- [ ] 8.5 swifT Exchange page listing files and row counts; reset; tests (0.5 d)

**Decisions needed**

1. File transfer: the agent downloads the files and imports them into swifT by hand (recommended for now, matches swifT's CSV import), or an automated transfer (SFTP or API, needs Toukei; later)?
2. Standard partner fee per visit type (Installation, Filter, Repair, Removal): amounts, or placeholders in metadata for now?
3. File layouts: wait for Toukei's import format, or start with our own layout (changeable in metadata) and align later?

### Round 3 total

Step 1 built · Step 2 ~2 d · Step 3 ~2.5 d · Step 4 ~3 d · Step 5 ~2.75 d · Step 6 ~2.5 d · Step 7 ~2.25 d · Step 8 ~3 d · **about 18 working days**, plus rehearsal and documentation.

---

## Remaining work

### Stripe webhook endpoint (CLAUDE.md Task 10) ⏸

- [ ] `DemoStripeWebhookHandler` at `/services/apexrest/stripe/webhook/demo/*`
- [ ] Resolve Contract by `Stripe_Sub_ID__c`; clean JSON error if not found
- [ ] Insert failed `Payment_History__c` (default reason `Card Expired (ERR-02)`) — the existing Flow does the rest
- [ ] Comment noting production needs Stripe signature verification
- [ ] Tests: success + contract-not-found
- [ ] Postman request for the presenter (needs an authenticated session or a Site path)

### Deferred UI (CLAUDE.md Tasks 3–5) ⏸

- [ ] `noritzCustomerHeader`: green/red status badge, plan, filter countdown
- [ ] `noritzPaymentHistory`: timeline with failed rows bold red
- [ ] `noritzAssetCard`: filter health
- [ ] Console app "NORITZ Subscription Console"
- [ ] Move the chat above the details panel so it's visible without scrolling

### Demo data (CLAUDE.md Task 7) ⏸

- [ ] `setup_demo_data.apex` to create Somchai, contract and asset from nothing (they already exist in this org; only needed for a fresh org)
- [ ] Asset filter due = today + 14 days, computed with `addDays` (see gotchas)

### Rehearsal (CLAUDE.md Task 11)

- [ ] Round 1: reset → Scenario 1 → reset → Scenario 2
- [ ] Round 2: reset → Scenario 1 → reset → Scenario 2
- [ ] Backup screen recording (console + phone)

### Housekeeping

- [ ] Update CLAUDE.md §2.1 / §2.5: standard `Contract.Status`, no `Subscription_Status__c`

---

## Gotchas (keep in mind)

- **LINE auth header:** the formula must use the principal parameter name exactly (`token`, lowercase), and the Named Credential needs "Allow Formulas in HTTP Header". Either missing → LINE 401.
- **Don't redeploy `externalCredentials/` casually:** it may reset the principal and drop the token.
- **Site guest user at API 67:** the guest's own access applies to Apex queries and DML even in a `without sharing` class. The webhook runs its lookups and insert in system mode, after the signature check.
- **Thai (Buddhist) calendar:** for a `th_TH` user, `Date.toStartOfMonth()` saves the year 2569. Use `d.addDays(1 - d.day())`. `Date.today()` and `addDays` are fine; `.year()` only displays 2569.
- **Stale components after deploy:** reload twice before rehearsing.
- **Contract status is one-way into Activated:** contracts are created as Pending Payment, then set Active; an Active contract can never go back to Pending Payment and can't be deleted.
- **Shared org:** other demo customers (Somsri Tephaluk, Somsak Bangna, contracts 00000102/103) were added by the Kamonphob user on 2026-09-23. The reset leaves them alone, but the recovery Flow runs for **any** failed payment.
- **Guest user and the LINE credential:** besides principal access, the guest permission set needs Read on User External Credentials, or the profile lookup fails silently (the account gets a placeholder name).
- **Standard related lists** (e.g. Payment History on the Account) aren't pushed live; the highlights, Path and chat are.

---

## Decisions log

| Date       | Decision                                                                                                          | Why                                                                                                           |
| ---------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| 2026-09-23 | Use standard `Contract.Status` for subscription state. **No `Subscription_Status__c`.** Overrides CLAUDE.md §2.1. | Status already holds Pending Payment / Active / Payment Failed.                                               |
| 2026-09-23 | Move `Payment Failed` from In Approval to the **Activated** category; reorder values.                             | Salesforce rejected Active → Payment Failed ("Choose a valid contract status"). Tested both directions after. |
| 2026-09-23 | Build only the LINE chat widget; defer header, payment timeline and asset card.                                   | User's call. Standard highlights, Path and related lists show the rest.                                       |
| 2026-09-23 | Real LINE OA integration is in scope (was a stretch goal).                                                        | User has a LINE OA account and wants the chat connected to it.                                                |
| 2026-09-23 | Refresh event named `LINE_Chat_Refresh__e` (not `Demo_Refresh__e`), published after commit.                       | Chat-specific; after-commit so the page never reads data before it's saved.                                   |
| 2026-09-23 | Scenario 1 button is a headless LWC quick action, not a Screen Flow.                                              | A screenless Flow leaves a "Your flow finished" pop-up on stage; the LWC is one click with a toast.           |
| 2026-09-23 | Scenario 2 automation is a record-triggered Flow, as in the spec; the LINE push runs in a queued job.             | The presenter can show the Flow; LINE can't be called inside the save.                                        |
| 2026-09-23 | Messages to the customer are in Thai.                                                                             | Matches the audience and the rest of the chat. The retry text is the spec's English sentence translated.      |
| 2026-09-25 | Automated checkout and retry messages switched to English; seeded chat history stays Thai.                        | User request. Retry text follows the spec wording.                                                            |
| 2026-09-23 | Seed script renamed to `reset_demo.apex` and extended to contract, account and payments.                          | Matches CLAUDE.md's name; one command resets everything.                                                      |

---

## Acceptance criteria (CLAUDE.md §5)

- [ ] Console record page matches the wireframe layout — ⏸ three columns exist; custom header / payment timeline deferred
- [ ] Status badge green when Active, red when Payment Failed — ⏸ no custom badge; the contract Status shows 🟢/🔴 and updates live
- [ ] Failed payment rows bold red with failure reason visible — ⏸ payment timeline deferred
- [x] LINE chat shows history, accepts an agent message, receives automated messages
- [x] Scenario 1 delivers a checkout link to the chat in one click
- [x] Scenario 2 updates contract, account and chat without a manual refresh (payment card deferred)
- [x] `reset_demo.apex` restores the pre-demo state and can be run repeatedly
- [x] Apex tests pass; no failing deploys
- [ ] Backup screen recording exists

---

## UI guideline (from the wireframe)

```
+---------------------------------------------------------------------------+
| HEADER: Somchai Sukhumvit | ● ACTIVE (green) | Plan: Premium | Filter: 14 days 🟢 |
+-------------------------+------------------------------+------------------+
| LEFT                    | CENTER                       | RIGHT            |
| - Customer details      | - Path                       | - Asset card     |
|   (Person Account)      | - Activity timeline          |   (filter health)|
| - LINE chat widget      | - Case log                   | - Contract       |
|   (live)                |                              |   details        |
|                         |                              | - Payment history|
|                         |                              |   timeline       |
|                         |                              |   (FAILED in red)|
+-------------------------+------------------------------+------------------+
```

Currently on the page: standard highlights (Status, plan, next filter date), Path on the Account's `Customer_Status__c`, details and **LINE chat** on the left, activity and cases in the centre, Assets / Contracts / Payment History related lists on the right.

**Visual rules:** SLDS tokens everywhere except the badge colours, the failed-row red and the LINE-green bubbles. THB amounts, en-GB dates.

---

## Open questions

- [ ] Path stages: wireframe shows Lead → Pending → Active → Renewal; the org has Pending Payment → Active → Payment Failed. Keep the org values?
- [ ] Right panel: three columns (current) or full-width bottom row as drawn?
- [ ] Should the two demo buttons also sit on Somchai's Account page, so the presenter never leaves the chat?
- [x] Stripe or Krungsri? **Krungsri** (Merchant Acquiring proposal, 2026-05-05); still mocked for the demo. See Round 3.
- [ ] Krungsri recurring billing is scheduled in Krungsri's own portal: does Salesforce generate monthly charges, or only record the results Krungsri posts back?
- [ ] Initial fee on top of the first month? Amount per plan?
- [ ] Presentation date
