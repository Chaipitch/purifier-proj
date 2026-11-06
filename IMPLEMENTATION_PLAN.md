# NORITZ Demo — Implementation Tracker

Target org: `noritz` (Developer Edition, `orgfarm-28f7eccd9f-dev-ed`)
Spec: [CLAUDE.md](CLAUDE.md) · Wireframe: [docs/wireframe.png](docs/wireframe.png) · Last updated: 2026-11-06

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

## Round 3 — full business flow, step by step (updated 2026-11-06 after the GBD meeting)

Source documents: _Subscription Business: Operational Overview_ (client), the Krungsri _Merchant Acquiring Services_ proposal (2026-05-05), the Toukei _swifT_ introduction, and GBD's _List of Requirements_ with the **MOM of 2026-11-06** (column I; our answers are the `[TSTH dev]` notes). Krungsri is the payment gateway; swifT (Toukei Thailand) is the core accounting system.

**Where things live**

| What                                   | Where                                                                                                                          |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Flow, 8 steps, Manual / Trigger / Scheduled tags | Web: "NORITZ Subscription Flow" artifact · draw.io: [docs/noritz-subscription.drawio](docs/noritz-subscription.drawio), pages 1–2 |
| Data model (objects, fields, relationships) | Web: "NORITZ Data Model" artifact · draw.io: same file, page 3                                                           |
| Estimate                                | Google Sheet "NORITZ Estimate WS V.3 – Procode", tab **V.4 – MOM 11-6** (procode 51.0 MD); tab **MOM 11-6 answers**           |

**Scope rules from the MOM (2026-11-06)**

- Contract is created by staff and sent as a PDF for sign-off; no automatic contract creation (MOM 11).
- No Experience Cloud: partners have no login; partner communication is manual (LINE / email) and staff update the Work Order (MOM 13, 24–27).
- Installation progress, asset registration and start of use are manual; Salesforce prepares the work order and the documents (MOM 5).
- Work orders are created from a per-product **Work Instruction Template** (master-detail); Service Cloud only, no Field Service or Knowledge licence (MOM 5, 22).
- swifT: Salesforce only exports CSV files (option 1, export button); swifT import, inventory allocation and storing swifT records in Salesforce are out of scope / phase 2 (MOM 15–18).
- Quote PDF uses the standard Quote template; contract, invoice, installation instruction and shipping label are Visualforce PDFs (MOM 11, 19, 22, 33).
- Invoices are issued by staff (button), not by an automatic monthly run (MOM 33).
- Monthly charging uses Krungsri's subscription schedule; retry ownership and iFrame depend on the Krungsri API (MOM 34).

### Step 1 — Customer adds the LINE OA ✅ built · 4.5 MD (production hardening)

- [x] LINE `follow` creates a Lead (LINE display name, `LINE_User_ID__c`, Lead Source = LINE).
- [x] Duplicate check on Lead, not Account: an existing open Lead or customer with the same LINE ID is reused (MOM 10). A standard duplicate rule covers Leads entered by hand (config).
- [x] Every message saved as `LINE_Message__c`; chat widget on Lead, Account and Case.

### Step 2 — Sign-up form inside LINE (LIFF) [ ] 4.5 MD

Agent clicks **Send sign-up form** → LINE button → form opens inside LINE (LIFF, Full) → customer submits → Lead updated, status **Form Submitted**, thank-you bubble, agent bell. Identity: the LIFF ID token is verified with LINE (`/oauth2/v2.1/verify`) and matched to the Lead by LINE user ID.

Lead fields: name, mobile, email, street, new `Subdistrict__c`, City (district), State (province), PostalCode, new `Installation_Location__c`, new `Preferred_Install_Date__c`, `Subscription_Plan__c`, new `Tax_ID__c` (**optional**, 13 digits), billing address or "same as installation", new `PDPA_Consent__c` + `PDPA_Consent_Date__c`.

- [ ] 2.1 Lead fields, status "Form Submitted", layout
- [ ] 2.2 Form page on the Salesforce Site with the LIFF SDK, Thai / English labels
- [ ] 2.3 Guest-safe Apex: verify the LIFF token, update the Lead, thank-you message; tests
- [ ] 2.4 **Send sign-up form** button
- [ ] 2.5 Reset puts the demo Lead back to "not yet submitted"

Needs from the client: a LINE Login channel under the **same provider** as the Messaging API channel, a LIFF app in it; send the LIFF ID and Login channel ID.

### Step 3 — Contract and first payment [ ] 5.0 MD + 3.0 MD notification verification

Staff convert the prospect (standard Convert; our code carries the LINE ID, form data and chat) → staff create the contract (`Contracts__c`, auto-number) → staff send the contract PDF and the first invoice in LINE → customer taps **I agree** (invoice status Agreed) → payment link sent automatically → customer pays on the Krungsri page (card, saved card or PromptPay QR; redirect, or iFrame if Krungsri allows) → Krungsri posts the result → **paid:** Payment History row, **Order + Order Product** created (for the swifT CSV), card token saved, contract **Pending Installation**, customer **Awaiting Installation**, LINE "payment received" → **failed:** LINE "try again" with the link.

No initial fee: the first payment is month 1 of 12 (Standard 900 / Premium 1,500 THB).

- [ ] 3.1 Payment fields (`Payment_Reference__c` replaces `Stripe_Sub_ID__c` on Lead and `Contracts__c`; `Payment_Method__c`, `Card_Token_Ref__c`, `Card_Last4__c`; `Payment_History__c.Gateway_Transaction_ID__c`); new statuses
- [ ] 3.2 "I agree" step on the invoice (LINE button → postback) and automatic payment link
- [ ] 3.3 Krungsri payment result endpoint (Post URL): resolve by `Payment_Reference__c`, JSON error if not found; tests for success, failure, not found
- [ ] 3.4 Stage 3.1 — notification verification: signature / hash check, duplicate handling, background processing, retries
- [ ] 3.5 Order + Order Product on the first successful payment
- [ ] 3.6 Lead conversion carries form data; reset; Simulate Payment Success stays as the demo backup

**Demo impact:** the demo today converts the Lead and creates the contract automatically on the first payment. The production flow above makes conversion and contract creation staff actions. **Decision (2026-11-06): leave the demo unchanged until the client signs off the production flow.**

### Step 4 — Shipping and installation [ ] 3.0 MD + PDFs

Paid order → **Work Order** created with the product's installation steps (copied from the Work Instruction Template as Work Order Line Items) → staff set date, time and address and confirm with the customer in the chat → staff print the **shipping label** and **installation instructions** (PDF) → staff send the job to the partner by LINE / email → partner installs → staff update the work order (serial no., photos as Files, install date) → staff **register the purifier** (or pick a Ready for Re-use unit) and set it **In Use** with the start date → contract Active, billing from the 1st of the next month.

- [ ] 4.1 `Work_Instruction_Template__c` (Product, Work Type) and `Work_Instruction_Step__c` (master-detail) — config ~1 MD outside procode
- [ ] 4.2 Flow / Apex: create the Work Order and copy the steps when the order is paid or a Case is opened for the product
- [ ] 4.3 Work Order fields: Partner, Contract, Asset, Template, Work Type, Scheduled Date, Shipment Status, Serial Number, Installation Fee, Travel Expense, Return Cost
- [ ] 4.4 Installation Partner record type on Account

Decisions kept from 2026-10-30: staff record the completion report (no partner form); billing starts on the **1st of the month after installation**; filter interval **6 months** in `Subscription_Setting__mdt`.

### Step 5 — Monthly billing, failed payments and renewal [ ] 4.0 + 3.0 + 1.5 MD

Staff issue the monthly invoice (**Issue Invoice** button: PDF saved as a File, link sent in LINE and by email) → Krungsri's subscription schedule charges the saved card on the billing date → result recorded → **paid:** "payment received" → **failed:** retry within the grace period (Krungsri or Salesforce, per the API) → still failing: service suspended, LINE link to update the card (existing recovery flow) → customer updates the card → service reactivated.

Renewal: 30 days before the end (`Renewal_Notice_Days__c`) LINE asks: **Renew 12 months / Continue monthly / End service** (postback buttons); no reply → reminder 7 days before, then continue monthly (assumption to confirm); End → Step 7.

- [ ] 5.1 Stage 5 — payment results from the schedule, failed-payment recovery, update card, renewal choice
- [ ] 5.2 Stage 5.1 — dunning: retry schedule, grace period, suspension, reactivation (may shrink if Krungsri retries)
- [ ] 5.3 Stage 5.2 — `Invoice__c` (own numbering; status Issued / Agreed / Paid) and the Issue Invoice button. The official tax invoice and receipt come from swifT.

### Step 6 — Filter care and repairs [ ] 3.5 MD

Filter: scheduled LINE reminder with time-slot buttons → customer picks a slot → Filter work order created from the template → partner replaces the filter (free) → staff close the work order; next filter date + 6 months.
Repair: customer reports in LINE or by phone → staff open a Case → fixed over chat? → if not, a Repair work order is created from the product's steps → partner visits (free) → repaired, or unit swapped on the same contract (old unit goes to Step 7 inspection) → Case closed, LINE message.

- [ ] 6.1 Time-slot quick replies on the filter reminder (postback) → Filter work order
- [ ] 6.2 Case gets `Asset__c` and `Subscription_Contract__c`; Repair work order from the Case
- [ ] 6.3 Unit swap keeps the contract and end date

Open with GBD: their sheet assumes filter timing is set by hand (row 43) and contract / asset updates are manual (row 46). The estimate automates both.

### Step 7 — Cancellation and return [ ] 3.0 MD

Customer asks to cancel (or taps End) → contract Termination Requested → before the end date? → cancellation fee from the metadata rule (None / Fixed / % of months left) → Removal work order → partner collects the unit → staff end the contract (Terminated), billing stops, customer Former Customer → return cost recorded on the work order → warehouse check → **Ready for Re-use** or **Terminated** → asset status file to swifT.

- [ ] 7.1 Request Termination action, fee rule in `Subscription_Setting__mdt`
- [ ] 7.2 Removal work order from the template
- [ ] 7.3 Asset statuses In Warehouse / In Use / Ready for Re-use / Terminated (replace Purchased / Installed / Obsolete); `Reuse_Returned_Units_First__c` switch

Open with GBD: their sheet assumes cancellation is tracked with Tasks and the removal work order is created by hand (rows 52–53). Open with the client: approval or quality check before re-use (row 55).

### Step 8 — Files for swifT [ ] 6.0 MD

New orders, contracts, payments (sales), asset status changes and return costs wait (`Exported_To_swifT__c` empty) → staff click **Export to swifT** (or a daily scheduled run) → CSV files in swifT's column layout (`swifT_Export_Layout__mdt`), only rows not yet sent, saved as Files on a `swifT_Export__c` record → staff download and import into swifT by hand. Contract number is the `Contracts__c` auto-number. Option 2 from the MOM (Data Export wizard) needs no development but exports Salesforce field names that must be re-mapped every time.

- [ ] 8.1 Export engine (layout in metadata, rows marked as exported)
- [ ] 8.2 Five files: order, contract, inventory / asset status, sales, return cost
- [ ] 8.3 Phase 2: bring swifT records (invoice / receipt / fixed-asset numbers) back into Salesforce

### PDFs [ ] 4.0 MD

- [ ] Contract (sign-off), invoice, shipment / installation instruction, shipping label — Visualforce, one class. Quote PDF uses the standard Quote template (config).

### Round 3 estimate (procode, V.4 – MOM 11-6)

| Line                                   | MD       |
| -------------------------------------- | -------- |
| Stage 1 LINE integration               | 4.5      |
| LINE chat screen + Customer History    | 3.0      |
| Stage 2 LIFF sign-up form              | 4.5      |
| Stage 3 Krungsri first payment         | 5.0      |
| Stage 3.1 Notification verification    | 3.0      |
| Stage 4 Work orders from templates     | 3.0      |
| Stage 5 Monthly billing and renewal    | 4.0      |
| Stage 5.1 Dunning                      | 3.0      |
| Stage 5.2 Issue invoice                | 1.5      |
| Stage 6 Filter care and repairs        | 3.5      |
| Stage 7 Cancellation and return        | 3.0      |
| Stage 8 swifT CSV export               | 6.0      |
| Visualforce PDFs                       | 4.0      |
| Integration testing                    | 3.0      |
| **Total**                              | **51.0** |

Outside procode (for the PM): remove Partner Experience (−6 MD); Quote template ~0.5 MD; template objects and Work Order fields ~1 MD config. The uploaded WS's procode rows sum to 49.5 although its header cell shows 46.50; check that formula.

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
| 2026-11-06 | Production scope follows the GBD MOM: staff create contracts, no partner portal, manual installation and asset registration, CSV export only. | GBD meeting, 6 Nov. Answers recorded as `[TSTH dev]` notes in GBD's List of Requirements. |
| 2026-11-06 | Work orders come from a per-product Work Instruction Template; invoices are a custom `Invoice__c` issued by staff; Order created on the first payment for swifT. | MOM rows 5, 12, 33. See the data model. |
| 2026-11-06 | Keep the custom `Contracts__c` and `Assets__c`; standard Order and Work Order get custom lookups to them. | The org already moved to the custom objects (2026-10-02). |
| 2026-11-06 | Demo stays as is (one-click conversion and contract on payment); no Round 3 build until sign-off. | Wait for the client to sign off the production flow. |

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
- [x] Monthly charging: Krungsri's subscription schedule runs it; Salesforce records the results (MOM 34). Retry ownership and iFrame depend on the Krungsri API (B-san).
- [x] Initial fee: none; the first payment is month 1 of 12.
- [ ] Contract sign-off: paper / scan, or an e-signature tool (not estimated)?
- [ ] Salesforce invoice numbering vs the swifT tax invoice and receipt.
- [ ] GBD alignment on automation the estimate includes but their sheet assumes manual: rows 35, 36, 43, 46, 52, 53.
- [ ] Approval or quality check before re-using a returned unit (row 55).
- [ ] Renewal: no reply means continue monthly?
- [x] Demo: keep it as is (automatic conversion and contract creation on payment) until the client signs off the production flow. Decided 2026-11-06.
- [ ] Presentation date
