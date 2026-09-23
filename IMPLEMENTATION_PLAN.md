# NORITZ Demo — Implementation Tracker

Target org: `noritz` (Developer Edition, `orgfarm-28f7eccd9f-dev-ed`)
Spec: [CLAUDE.md](CLAUDE.md) · Last updated: 2026-09-23

**Legend:** `[x]` done · `[ ]` to do · ⛔ blocked on input

---

## Current focus: LINE chat widget only (from 2026-09-23)

Scope is narrowed to the `noritzLineChat` widget on the Account record page, connected to the real LINE OA. The other widgets, the console app, the Path, the Flows and the Stripe webhook are **deferred**.

**Stage A — widget working locally**

- [x] `LINE_Message__c` + fields (adds `LINE_User_ID__c`, `LINE_Message_ID__c`, `Delivery_Status__c`; `Contract__c` deferred)
- [x] `LINE_Chat_Refresh__e` platform event + `LineMessageTrigger` (publishes on insert and delete)
- [x] `NoritzLineChatController` + tests (100% coverage)
- [x] Permission set `LINE_Chat_User`, assigned to the admin user
- [x] `noritzLineChat` LWC (LWC Jest tests dropped at user's request)
- [x] Added to `Account_Record_Page`, left column under the details
- [x] `scripts/apex/seed_line_chat.apex`, run once
- [x] Check in the browser: page is the one Somchai's record uses, history shows, send works, live update from an Apex insert (checked 2026-09-23)
- Refresh method: **platform event via empApi (confirmed working, no polling traffic)**; falls back to 3 s polling automatically if the subscription fails.
- [ ] Layout: at 1440×900 the chat sits below the fold because the details panel above it is tall. Decide: move the chat above the details, or put the details in a collapsed tab.

**Stage B — connect to LINE OA** (deployed 2026-09-23, waiting on your setup)

- [x] External Credential `LINE_Messaging` + Named Credential `LINE_Messaging_API` (no token in source)
- [x] `LINE_Settings__c` custom setting (no secret in source)
- [x] `LineMessagingService` push; controller pushes before saving, keeps `Delivery_Error__c` on failure
- [x] `LineWebhookHandler`: signature check, dedupe, unknown senders saved without an account
- [x] Site `line_webhook` + `LINE_Webhook_Guest` permission set assigned to the guest user
- [x] Apex tests: 16 passing, coverage 98–100%
- [x] Public endpoint reachable (returns "Channel secret is not configured" until step 2 below)
- [x] Channel access token entered in the External Credential principal (parameter name `token`, lowercase)
- [x] Channel secret entered in Custom Settings → LINE Settings
- [x] Webhook URL set in LINE Developers, "Use webhook" on, auto-response off
- [x] Somchai's `LINE_User_ID__c` linked from the first test message
- [x] Salesforce → phone: widget send delivered (Sent)
- [x] Phone → Salesforce: reply appears live in the widget (confirmed by user 2026-09-23)
- [x] Chat reset to seed history after testing

**Stage B gotchas (fixed, keep in mind):**

- Header formula must use the principal parameter name exactly (`token`), and the Named Credential needs "Allow Formulas in HTTP Header" on. Either one missing → LINE 401.
- At API 67 the Site guest user's access applies to Apex queries and DML even in a `without sharing` class. The webhook runs its lookups and insert in system mode, after the signature check.
- Don't redeploy `externalCredentials/` casually: it may reset the principal and drop the token.

Webhook URL: `https://orgfarm-28f7eccd9f-dev-ed.develop.my.salesforce-sites.com/line/services/apexrest/line/webhook`

---

## Progress at a glance (full demo, mostly deferred)

| #   | Task                                     | Est.  | Status                              |
| --- | ---------------------------------------- | ----- | ----------------------------------- |
| 0   | Project scaffolding (git)                | 0.1 h | Not started                         |
| 1   | Verify org + fix Contract Status mapping | 0.5 h | In progress (verified, fix pending) |
| 2   | `LINE_Message__c` object                 | 0.5 h | Not started                         |
| 3   | Console app + record page                | 1.0 h | Not started                         |
| 4   | `noritzCustomerHeader` LWC               | 2.0 h | Not started                         |
| 5   | `noritzPaymentHistory` LWC               | 1.5 h | Not started                         |
| 6   | `noritzLineChat` LWC                     | 2.5 h | Not started                         |
| 7   | Demo data + reset scripts                | 1.5 h | Not started                         |
| 8   | Live refresh (Platform Event)            | 1.0 h | Not started                         |
| 9   | Flows — Scenario 1 & 2                   | 2.5 h | Not started                         |
| 9.5 | Real LINE OA integration                 | 3.0 h | ⛔ Needs credentials                |
| 10  | Stripe webhook handler + tests           | 1.0 h | Not started                         |
| 11  | End-to-end rehearsal + backup recording  | 1.0 h | Not started                         |

---

## Decisions log

| Date       | Decision                                                                                                          | Why                                                                                                                |
| ---------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| 2026-09-23 | Use standard `Contract.Status` for subscription state. **No `Subscription_Status__c`.** Overrides CLAUDE.md §2.1. | Status already holds Pending Payment / Active / Payment Failed.                                                    |
| 2026-09-23 | Move `Payment Failed` from the In Approval category to **Activated**.                                             | Salesforce won't move an Activated contract back to In Approval, so `Active → Payment Failed` would fail on stage. |
| 2026-09-23 | Path runs on `Contract.Status`.                                                                                   | Follows from the decision above.                                                                                   |
| 2026-09-23 | Real LINE OA integration is in scope (was a stretch goal).                                                        | User has a LINE OA account and wants the chat widget connected to it.                                              |

**Contract Status rules to build around:**

- Contracts are created as `Pending Payment`, then updated to `Active`. They can't be created straight into `Active`.
- An active contract can never return to `Pending Payment`, and can't be deleted. Reset only restores `Active`.

---

## UI guideline (from the wireframe)

Source: [docs/wireframe.png](docs/wireframe.png). The highlighted items in the wireframe are the ones the demo depends on most.

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

| Region | Component              | Built as                                       | Must show                                                                                                      |
| ------ | ---------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Header | `noritzCustomerHeader` | Custom LWC                                     | Name · status badge (green Active / red Payment Failed) · **Plan: Premium** · **Filter: N days** with 🟢/🟡/🔴 |
| Left   | Customer details       | Standard Record Detail / Highlights fields     | Person Account fields: name, mobile, LINE user id, customer status                                             |
| Left   | `noritzLineChat`       | Custom LWC                                     | **Live** LINE chat, history, send box, link buttons                                                            |
| Center | Path                   | Standard Path on Contract `Status`             | Current subscription stage                                                                                     |
| Center | Activity timeline      | Standard Activities component                  | —                                                                                                              |
| Center | Case log               | Standard Cases related list                    | —                                                                                                              |
| Right  | Asset card             | Custom LWC (or header data reuse)              | NORITZ Pure Water X1, serial, next filter date, **filter health indicator**                                    |
| Right  | Contract details       | Standard related record / Dynamic Related List | Plan, Stripe sub id, next billing date, status                                                                 |
| Right  | `noritzPaymentHistory` | Custom LWC                                     | **Timeline** of payments, newest first, **FAILED rows bold red** with reason                                   |

**Layout choice:** three columns side by side, as in CLAUDE.md §3. In the wireframe the right panel is drawn as a bottom row. A bottom row would push the payment history below the fold on a projector, and the audience needs to see the badge, the chat and the payment history at the same time during Scenario 2. Change to a bottom row if the client insists on the drawing.

**Differences from the wireframe to confirm with the client:**

- **Path stages.** The wireframe shows _Lead → Pending → Active → Renewal_. Contract `Status` has _Pending Payment → Active → Payment Failed_. There is no Lead or Renewal value, and adding them would need new status values. For now the Path runs on the existing values.
- **Payment history as a timeline.** The wireframe says "timeline", not table. Build it as a vertical timeline (date, amount, status), not a data table.

**Visual rules:**

- SLDS tokens everywhere, except the badge colours, the failed-row red and the LINE-green bubbles.
- THB amounts, en-GB dates (e.g. 01 Oct 2026).
- The badge, the failed row and the retry message must all change within ~2 s of Scenario 2, with no page refresh.

---

## Task checklists

### 0. Project scaffolding

- [ ] `git init` + initial commit
- [ ] Commit after every task below

### 1. Verify org + fix Contract Status mapping

- [x] Log in and describe Account, Contract, Asset, Payment_History__c
- [x] Confirm all §1 fields exist and picklist values match
- [x] Confirm Person Accounts are enabled (already on)
- [x] Read the Contract Status category mapping (Pending Payment = Draft, Active = Activated, Payment Failed = In Approval)
- [ ] Retrieve `StandardValueSet:ContractStatus`, move `Payment Failed` to Activated, deploy
- [ ] Test on a throwaway contract: create `Pending Payment` → `Active` → `Payment Failed` → `Active`
- [ ] Clean up the throwaway contract
- [ ] Update CLAUDE.md §2.1 / §2.5 to remove `Subscription_Status__c`

### 2. `LINE_Message__c` object

- [ ] `Account__c` — Lookup → Account
- [ ] `Contract__c` — Lookup → Contract (optional)
- [ ] `Direction__c` — Picklist: Inbound, Outbound
- [ ] `Message_Body__c` — Long Text Area (4000)
- [ ] `Sent_At__c` — DateTime, default NOW()
- [ ] `Message_Type__c` — Picklist: Text, Checkout Link, Payment Retry
- [ ] Deploy and re-describe to confirm

### 3. Console app + record page

- [ ] Lightning app "NORITZ Subscription Console" (console navigation)
- [ ] Nav items: Account, Contract, Asset, Case
- [ ] Person Account record page: header + three columns (see UI guideline)
- [ ] Left: customer details, LINE chat
- [ ] Center: Path on Contract `Status`, activity timeline, case log
- [ ] Right: asset card, contract details, payment history
- [ ] Check at projector resolution: header, chat and payment history visible without scrolling

### 4. `noritzCustomerHeader` LWC

- [ ] Apex controller: one cacheable query for Account + active Contract + Asset
- [ ] Customer name (large)
- [ ] Status badge: green Active / red Payment Failed / grey Pending Payment
- [ ] Plan name and price
- [ ] "Next filter: N days" with 🟢/🟡/🔴 from `Filter_Status_Icon__c`
- [ ] Re-renders on record change
- [ ] Asset card for the right panel (`noritzAssetCard`): product name, serial, next filter date, filter health indicator; reuses the same Apex query

### 5. `noritzPaymentHistory` LWC

- [ ] Payments for the contract, newest first, shown as a vertical timeline (not a table)
- [ ] Failed entries bold red with `Failure_Reason__c` inline
- [ ] Amount formatted as THB
- [ ] Updates within ~2 s of a failure being inserted

### 6. `noritzLineChat` LWC

- [ ] Bubbles: inbound left, outbound right (LINE green)
- [ ] Timestamps
- [ ] Agent send box creates an Outbound record
- [ ] Auto-scroll to newest
- [ ] Checkout Link / Payment Retry URLs render as tappable buttons

### 7. Demo data + reset scripts

- [ ] `scripts/apex/setup_demo_data.apex`
  - [ ] Somchai Sukhumvit, Person Account, Active
  - [ ] Premium contract `sub_demo_12345`, created as Pending Payment then set to Active, reused if it already exists
  - [ ] Next billing = 1st of current month
  - [ ] Asset NORITZ Pure Water X1, `NZ-2026-9981`, filter due = today + 14 days (computed)
  - [ ] 2–3 successful payments
  - [ ] 2–3 chat messages of history
- [ ] `scripts/apex/reset_demo.apex`
  - [ ] Delete demo account's Payment_History__c and LINE_Message__c
  - [ ] Contract → `Active`, Account → `Active`
  - [ ] Re-seed chat history
  - [ ] Never deletes the contract
  - [ ] Run twice back-to-back, same result both times
- [ ] No hard-coded record Ids

### 8. Live refresh

- [ ] Platform Event `Demo_Refresh__e`
- [ ] Subscribed via `lightning/empApi` in payment history, chat and header components
- [ ] Fallback if needed: 2 s polling behind a component property
- [ ] Record which method was used: _______

### 9. Flows

- [ ] **Scenario 1:** Quick Action "Send Stripe Checkout Link" on Contract → Screen Flow → Outbound Checkout Link message (`https://checkout.stripe.com/demo/sub_demo_12345`) → publish refresh event
- [ ] **Scenario 2:** record-triggered Flow on Payment_History__c (after insert, `Status__c = Failed`)
  - [ ] Contract `Status` → Payment Failed
  - [ ] Account `Customer_Status__c` → Payment Suspended
  - [ ] Outbound Payment Retry message
  - [ ] Publish refresh event
- [ ] Quick Action "Simulate Payment Failure" on Contract

### 9.5 Real LINE OA integration ⛔

**Inputs needed from you:**

- [ ] ⛔ Channel Access Token (long-lived)
- [ ] ⛔ Channel Secret
- [ ] ⛔ Real `LINE_User_ID__c` of a test account that has added the OA as a friend
- [ ] ⛔ Register the webhook URL in the LINE Developers console (after it's deployed)

**Outbound (Salesforce → LINE):**

- [ ] Named Credential + External Credential for `https://api.line.me`
- [ ] `LineMessagingService` Apex (push API)
- [ ] Called from the chat send box
- [ ] Invocable action added to Scenario 1 and 2 Flows

**Inbound (LINE → Salesforce):**

- [ ] `LineWebhookHandler` Apex REST at `/services/apexrest/line/webhook/*`
- [ ] Verify `X-Line-Signature` (HMAC-SHA256 with the channel secret)
- [ ] Create Inbound `LINE_Message__c`, match Account by `LINE_User_ID__c`, publish refresh event
- [ ] Salesforce Site + least-privilege Guest User access

### 10. Stripe webhook handler

- [ ] `DemoStripeWebhookHandler` at `/services/apexrest/stripe/webhook/demo/*`
- [ ] Resolve Contract by `Stripe_Sub_ID__c`, clean JSON error if not found
- [ ] Insert failed Payment_History__c (default reason `Card Expired (ERR-02)`)
- [ ] Comment noting production needs Stripe signature verification
- [ ] Test class: success case + contract-not-found case
- [ ] Postman request saved for the presenter

### 11. Rehearsal

- [ ] Round 1: reset → Scenario 1 → reset → Scenario 2
- [ ] Round 2: reset → Scenario 1 → reset → Scenario 2
- [ ] Real LINE round trip: push reaches phone, phone reply appears in the widget
- [ ] Fix anything that flickers, lags > 2 s, or needs a manual refresh
- [ ] Backup screen recording (console + phone)

---

## Acceptance criteria (CLAUDE.md §5)

- [ ] Console record page matches the wireframe layout
- [ ] Status badge green when Active, red when Payment Failed
- [ ] Failed payment rows bold red with failure reason visible
- [ ] LINE chat shows history, accepts an agent message, receives automated messages
- [ ] Scenario 1 delivers a checkout link to the chat in one click
- [ ] Scenario 2 updates contract, account, chat and payment card without a manual refresh
- [ ] `reset_demo.apex` restores pre-demo state and can be run repeatedly
- [ ] Apex tests pass; no failing deploys
- [ ] Backup screen recording exists

---

## Open questions

- [ ] Path stages: wireframe shows Lead → Pending → Active → Renewal; org has Pending Payment → Active → Payment Failed. Keep the org values?
- [ ] Right panel: three columns (current plan) or full-width bottom row as drawn?
- [ ] Stripe or Krungsri? (mocked either way)
- [ ] Presentation date
