# NORITZ Demo — Implementation Tracker

Target org: `noritz` (Developer Edition, `orgfarm-28f7eccd9f-dev-ed`)
Spec: [CLAUDE.md](CLAUDE.md) · Wireframe: [docs/wireframe.png](docs/wireframe.png) · Last updated: 2026-09-23

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
| Apex tests                                                   | ✅ 26 pass | Coverage 95–100% on every class                                     |
| Stripe webhook endpoint (Task 10)                            | ⏸ Deferred | Second way to trigger Scenario 2, from Postman                      |
| Header badge, payment timeline, asset card LWCs              | ⏸ Deferred | User chose the chat widget only; standard components cover the rest |
| Console app "NORITZ Subscription Console" (Task 3)           | ⏸ Deferred | Demo runs in the existing **Service Console** app                   |
| Chat position on the page                                    | ⏸ Deferred | Below the fold at 1440×900; user chose not to move it               |
| Rehearsal + backup screen recording (Task 11)                | [ ] To do  | Use the run-book below                                              |
| CLAUDE.md §2.1 / §2.5 still mention `Subscription_Status__c` | [ ] To do  | Update so a later session doesn't create the field                  |

---

## Demo run-book

### Before the audience arrives

1. **Reset the demo** (safe to run any number of times; only touches Somchai and Meng): click **Reset Demo** on any Contract page. The page reloads itself. From a terminal instead:
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
3. The phone receives the Thai message with `https://checkout.stripe.com/demo/sub_demo_12345`.
4. Switch to Somchai's tab: the chat already shows the green bubble with an **Open checkout** button.

**Optional live chat moment:** type a reply on the phone → it appears in the widget within ~2 s. Type an answer in the widget and press Enter → it arrives on the phone.

### Beat 4 — Scenario 2: Payment Failure & Auto Recovery (the highlight)

1. On the Contract tab, click **Simulate Payment Failure**.
2. Orange toast: "Payment failure simulated — Card Expired (ERR-02). Recovery is running."
3. Within ~2 s, no refresh: contract Status flips **🟢Active → 🔴Payment Failed**.
4. The phone receives the Thai retry message with the `.../demo/sub_demo_12345/update-payment` link.
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
- [x] Thai message with the plan name and mock link `https://checkout.stripe.com/demo/<Stripe_Sub_ID__c>`.

### Scenario 2 — Payment Failure & Auto Recovery

- [x] Contract status values: Pending Payment (Draft) → Active (Activated) → Payment Failed (Activated).
- [x] Record-triggered Flow `Payment_Failure_Recovery` on `Payment_History__c` (after insert, `Status__c = Failed`): Contract → Payment Failed, Account → Payment Suspended, publish refresh, call `SendPaymentRetryAction`.
- [x] `SendPaymentRetryAction` queues a job that pushes the Thai retry message (`.../demo/<sub>/update-payment`) and saves it as Payment Retry.
- [x] "Simulate Payment Failure" on the Contract: headless LWC `noritzSimulatePaymentFailure` → `SimulatePaymentFailureAction.simulate` inserts a failed payment (plan price, `Card Expired (ERR-02)`), then refreshes the contract page.

### Reset

- [x] `DemoResetAction.reset()`: deletes Somchai's payments and chat; contract → Active, Premium, `sub_demo_12345`, next billing 1st of this month; account → Active; 2 successful payments; 3 chat messages. Meng: payments and chat deleted except the "[Added the OA as a friend]" line, contract Payment Failed → Active, account → Active. Other customers are untouched.
- [x] **Reset Demo** button on the Contract page (third action; headless LWC `noritzResetDemo`), toast then page reload, for the non-technical BA. `scripts/apex/reset_demo.apex` now just calls `DemoResetAction.reset()`. Tests: `DemoResetActionTest` (3).

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
- [ ] Stripe or Krungsri? (mocked either way)
- [ ] Presentation date
