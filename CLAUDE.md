# HANDOFF — NORITZ Thailand B2C Water Purifier Subscription Demo

**For:** Claude Code
**Target:** Salesforce Developer Edition org (demo + PoC only — never a production org)
**Remaining budget:** ~3 days (7.5 h/day)
**Goal:** a Lightning Service Console demo for Noritz Thailand covering three things — a clean single-screen console, a live LINE chat experience, and an automated payment-failure recovery scene.

---

## 0. Read this first

- This is a **demo**. Mock data and simplified Flows are explicitly acceptable. Do not build real backend integrations unless a task below says so.
- **Do not enable Person Accounts, delete fields, or delete objects** without asking. Person Accounts in particular is irreversible.
- The whole build is judged on how it *looks and behaves during a 10-minute live presentation*. Visual polish and "nothing breaks on stage" beat architectural purity every time.
- Everything must be re-runnable: the demo will be rehearsed and presented several times, so a one-click reset is a hard requirement (Task 7).

---

## 1. Current state

Objects and fields are **already created in the org**. Assume this schema exists, but verify before writing code (Task 1).

### Account (Person Account)
| API Name | Type | Notes |
|---|---|---|
| `Name` | Text | e.g. Somchai Sukhumvit |
| `PersonMobilePhone` | Phone | Thai mobile format |
| `LINE_User_ID__c` | Text | test LINE account ID |
| `Customer_Status__c` | Picklist | Prospect, Active, Payment Suspended |

### Contract
| API Name | Type | Notes |
|---|---|---|
| `AccountId` | Lookup | to the Person Account |
| `Status` | Picklist | standard — see warning in §2 |
| `Subscription_Plan__c` | Picklist | Standard (900 THB), Premium (1,500 THB) |
| `Stripe_Sub_ID__c` | Text | e.g. `sub_demo_12345` |
| `Next_Billing_Date__c` | Date | 1st of current month |

### Asset
| API Name | Type | Notes |
|---|---|---|
| `Name` | Text | NORITZ Pure Water X1 |
| `SerialNumber` | Text | NZ-2026-9981 |
| `Next_Filter_Replacement__c` | Date | ~14 days from today |
| `Filter_Status_Icon__c` | Formula (Text) | 🟢 OK / 🟡 due within 30 days / 🔴 overdue |

### Payment_History__c
| API Name | Type | Notes |
|---|---|---|
| `Contract__c` | Master-Detail | to Contract — **required**, see §2 |
| `Amount__c` | Currency (THB) | |
| `Status__c` | Picklist | Success, Failed |
| `Failure_Reason__c` | Text | e.g. Card Expired (ERR-02) |

---

## 2. Known traps — decisions already made

These were found while reviewing the spec. Build to the decision, not to the original spec text.

1. **Contract Status.** The standard `Status` field is bound to status categories (Draft / In Approval / Activated). Activated contracts lock fields and can't move freely between categories. **Decision:** add and drive everything from a custom `Subscription_Status__c` picklist on Contract — `Pending Payment`, `Active`, `Payment Failed`. Leave standard `Status` alone (keep it in Draft category). Create this field if it isn't there yet.
2. **Digital Engagement is not available in Developer Edition.** **Decision:** the LINE chat is a **mock LWC** backed by a custom `LINE_Message__c` object. Create that object if it doesn't exist (§3, Task 2). A real LINE Messaging API push is an optional stretch goal only — do not start it until Tasks 1–9 are done and green.
3. **The Apex sample in the spec is broken.** It inserts a `Payment_History__c` without `Contract__c`, which fails because the field is a required Master-Detail. The rewritten handler must resolve the Contract via `Stripe_Sub_ID__c` from the payload.
4. **Styling limits.** Standard highlights panels can't render coloured badges, and standard related lists can't render bold red rows. Both the header and the payment card must be custom LWCs.
5. **Path field.** The spec's wireframe Path (Lead → Pending → Active → Renewal) matches no field in the data model. **Decision:** run the Path on Contract `Subscription_Plan__c`… no — run it on `Subscription_Status__c` with the three values above. Flag it to the user if that looks wrong.
6. **"Stripe Hosted Checkout (Krungsri Payment Gateway)"** names two different providers. For the demo, everything Stripe-side is mocked, so this doesn't block the build. It is an open question for the client, not for you.

---

## 3. Build tasks, in order

Work in an SFDX project with source tracking and deploy with `sf project deploy start`. Commit after each task. Estimated hours in brackets.

### Task 1 — Verify the org [0.5 h]
Authenticate, then describe the objects and confirm every API name in §1 actually exists and picklist values match. Produce a short diff of anything missing, and create the missing pieces before moving on. Do not assume — a wrong API name discovered on Day 3 costs far more than checking now.

```
sf org login web --alias noritzdemo
sf sobject describe --sobject Payment_History__c --target-org noritzdemo
```

### Task 2 — `LINE_Message__c` mock chat object [0.5 h]
Create if absent:
- `Account__c` (Lookup → Account)
- `Contract__c` (Lookup → Contract, optional)
- `Direction__c` (Picklist: Inbound, Outbound)
- `Message_Body__c` (Long Text Area, 4000)
- `Sent_At__c` (DateTime, default NOW)
- `Message_Type__c` (Picklist: Text, Checkout Link, Payment Retry)

### Task 3 — Service Console app + record page skeleton [1.0 h]
Lightning app "NORITZ Subscription Console", console navigation, Account/Contract/Asset/Case in the nav. Person Account record page using a three-region template, laid out to match the wireframe:

```
[ Header: name | status badge | plan | next filter date ]
[ Left: customer details, LINE chat ][ Center: Path, activity timeline, cases ][ Right: asset card, contract, payment history ]
```

### Task 4 — `noritzCustomerHeader` LWC [2.0 h]
Apex-backed (`@AuraEnabled(cacheable=true)`) — one query returning the Account plus its active Contract and Asset.
- Customer name, large.
- Status badge: **green** when `Subscription_Status__c = Active`, **red** when `Payment Failed`, grey when `Pending Payment`.
- Plan name and price.
- "Next filter: N days" with the 🟢/🟡/🔴 indicator from `Filter_Status_Icon__c`.
- Must re-render when the record changes (see Task 8 refresh strategy).
Use SLDS tokens, not hand-rolled CSS colours, except for the badge accents.

### Task 5 — `noritzPaymentHistory` LWC [1.5 h]
Recent `Payment_History__c` for the customer's contract, newest first.
- `Status__c = Failed` rows in **bold red**, with `Failure_Reason__c` shown inline.
- Amount formatted as THB.
- This is the component the audience stares at during the highlight scene, so it must update within ~2 seconds of the failure being injected.

### Task 6 — `noritzLineChat` LWC [2.5 h]
Chat-bubble UI over `LINE_Message__c`.
- Inbound left / outbound right, LINE-ish green for outbound bubbles, timestamps.
- Agent send box → creates an Outbound record.
- Auto-scroll to newest.
- Checkout-link and payment-retry messages render the URL as a tappable button — this is what sells the "live LINE" story.

### Task 7 — Demo data + reset scripts [1.5 h]
Two anonymous Apex scripts in `scripts/apex/`:
- `setup_demo_data.apex` — Somchai Sukhumvit (Person Account, Active), Premium contract (`sub_demo_12345`, next billing 1st of month), NORITZ Pure Water X1 asset (`NZ-2026-9981`, filter due in **14 days from run date** — compute it, never hard-code), 2–3 successful payments, 2–3 chat messages of history.
- `reset_demo.apex` — delete all Payment_History__c and LINE_Message__c for the demo account, restore Contract to Active and Account to Active, re-seed the chat history. Must be safe to run repeatedly and must leave the org in the exact pre-demo state.

### Task 8 — Live refresh [1.0 h]
The flows below change records the user is already looking at. Without a refresh mechanism the demo looks dead.
- Preferred: a Platform Event (`Demo_Refresh__e`) published by the Flow, subscribed by the LWCs via `lightning/empApi`.
- Fallback if empApi misbehaves: 2-second polling in the chat and payment components, switched on by a component property.
Pick one, make it work, and note which you used.

### Task 9 — Flows and the two scenarios [2.5 h]

**Scenario 1 — Quick Signup.** Quick Action "Send Stripe Checkout Link" on Contract → Screen Flow → creates an Outbound `LINE_Message__c` of type Checkout Link with a mock URL (`https://checkout.stripe.com/demo/sub_demo_12345`) → publishes the refresh event. The link appears in the chat within ~2 seconds.

**Scenario 2 — Payment Failure & Auto Recovery (the highlight scene).** Record-triggered Flow on `Payment_History__c` after insert, entry condition `Status__c = Failed`:
1. Contract `Subscription_Status__c` → `Payment Failed`
2. Account `Customer_Status__c` → `Payment Suspended`
3. Create Outbound `LINE_Message__c`, type Payment Retry: *"Payment failed for your monthly subscription. Please update your payment method using this link: [URL]"*
4. Publish the refresh event

Provide **two ways to trigger it**, because the presenter will want a choice on the day:
- A "Simulate Payment Failure" quick action on Contract (safest — one click, no second screen).
- The Apex REST endpoint below, called from Postman so it looks like a genuine Stripe webhook.

### Task 10 — Rewritten webhook handler [1.0 h]
`DemoStripeWebhookHandler` at `/services/apexrest/stripe/webhook/demo/*`:
- Parse the body as JSON, read the subscription id and amount.
- Resolve the Contract by `Stripe_Sub_ID__c`; return a clean JSON error if not found rather than throwing.
- Insert `Payment_History__c` with `Contract__c` populated, `Status__c = 'Failed'`, `Failure_Reason__c` from the payload (default `Card Expired (ERR-02)`).
- Return `{"status":"success",...}`.
- Include a test class with a positive case and a contract-not-found case. **Do not implement Stripe signature verification** — it's out of scope for the demo, but note in the code comments that production needs it.

### Task 11 — End-to-end rehearsal [1.0 h]
Run reset → scenario 1 → reset → scenario 2, twice, in the console as the presenter will. Fix anything that flickers, lags, or needs a manual page refresh. Then record a short screen capture as a backup in case the live demo fails.

### Stretch (only if everything above is green)
Real LINE push via Named Credential to `https://api.line.me/v2/bot/message/push`, called from an Invocable Apex action in the Scenario 2 Flow. Needs a LINE OA channel access token and a real `LINE_User_ID__c`. Ask the user for credentials rather than inventing them.

---

## 4. Demo narrative (what the presenter will say)

Build so these five beats are smooth:

1. Open Somchai's record — everything on one screen, green Active badge, filter due in 14 days.
2. Walk the contract Path and the asset card.
3. Trigger Scenario 1 — checkout link lands in LINE chat, live.
4. Trigger Scenario 2 — payment fails. Badge flips to **red**, payment row goes **bold red**, retry message appears in LINE. All within about two seconds, no page refresh.
5. Reset, ready for the next run.

---

## 5. Acceptance criteria

- [ ] Console record page matches the wireframe layout.
- [ ] Status badge is green when Active and red when Payment Failed.
- [ ] Failed payment rows are bold red with the failure reason visible.
- [ ] LINE chat shows history, accepts an agent message, and receives automated messages.
- [ ] Scenario 1 delivers a checkout link to the chat in one click.
- [ ] Scenario 2 updates contract, account, chat and payment card without a manual refresh.
- [ ] `reset_demo.apex` returns the org to the pre-demo state and can be run repeatedly.
- [ ] Apex test class passes; no failing deploys.
- [ ] Backup screen recording exists.

---

## 6. Conventions

- All custom API names prefixed with the object's domain; no abbreviations that aren't in §1.
- LWCs in `force-app/main/default/lwc/`, named `noritz*`.
- SLDS design tokens for everything except the badge and failed-row accents.
- THB currency, `en-GB`-style dates in the UI; Thai names in demo data.
- No hard-coded record ids anywhere — resolve by `Stripe_Sub_ID__c`, `SerialNumber`, or name.
- Mock URLs must be obviously mock (`/demo/` in the path) so nobody mistakes them for live Stripe links.

---

## 7. Open questions for the user (don't block on these)

1. Should the Path run on Contract `Subscription_Status__c`? The spec's Path values don't exist in the data model.
2. Stripe or Krungsri? Both are named in the spec. Mocked either way for the demo.
3. Is a real LINE OA test channel available, with an access token and a user id?
4. Presentation date — it decides whether the stretch goal is worth starting.
