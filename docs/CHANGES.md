# NORITZ Demo — Changes

Newest first. Each entry lists what changed for the people using the demo, then the metadata behind it.

---

## 2026-10-02 — Contracts and assets move to custom objects

### What's different for users

- **Contracts and assets are now the consultant's custom objects**, `Contracts__c` and `Assets__c`. The demo buttons moved with them: Send Stripe Checkout Link, Simulate Payment Failure, Simulate Payment Success and Reset Demo are on the custom contract; Send Filter Reminder is on the custom asset.
- **The contract page has a Status path**: Pending Payment → Active → Payment Failed.
- **Reset Demo sets Somchai up from scratch.** It creates his Premium contract and NORITZ Pure Water X1 if they're missing, and resets the filter date to 14 days from today on every run.
- **A converted customer's contract keeps a link to the lead** it came from.
- **A Lead's Subscription Plan is no longer wiped when it's saved.** The consultant's **[Lead] Update highlight panel** flow copied the plan (and next filter date) from the Lead's standard Contract and Asset, and wrote blank when there were none, which is always the case for an open LINE lead. It now reads `Contracts__c` and `Assets__c`, copies only when one exists, and skips Leads that are being created.
- **Dates are always AD (2026), never Buddhist (2569).** Apex date maths goes through the new `GregorianDates` class, the components pin the Gregorian calendar, and `scripts/apex/use_gregorian_locale.apex` moves Thai-locale users to a locale whose standard pages show AD.

### Metadata

| Area            | Added / changed                                                                                                                                                                                                                                                                             |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fields          | `Payment_History__c.Subscription_Contract__c`, a new master-detail to `Contracts__c` that replaces `Contract__c` (deleted from the org after the deploy); `Assets__c.Last_Filter_Reminder__c`                                                                                               |
| Apex            | `DemoResetAction`, `LeadConversionService`, `CustomerHistoryController`, `SendCheckoutLinkAction`, `SimulatePaymentFailureAction`, `SimulatePaymentSuccessAction`, `SendPaymentRetryAction`, `SendPaymentSuccessAction`, `SendFilterReminderAction` and their tests                         |
| Flows           | `Payment_Failure_Recovery`, `Payment_Success_Recovery` (update `Contracts__c.Status__c`), `Filter_Reminder_Daily` (runs on `Assets__c`)                                                                                                                                                     |
| Actions         | `Contract.*` → `Contracts__c.*`, `Asset.Send_Filter_Reminder` → `Assets__c.Send_Filter_Reminder`                                                                                                                                                                                            |
| Pages & layouts | New `NORITZ_Contract_Record_Page` (actions, path) and `NORITZ_Asset_Record_Page`; Status path (created in Setup); standard Assets and Contracts related lists removed from the Account and Lead pages; Lead layout related lists re-pointed; demo buttons removed from the standard layouts |
| LWC             | `noritzCustomerHistory` (custom-object field names and links)                                                                                                                                                                                                                               |
| Permission sets | `LINE_Chat_User`: access to `Contracts__c`, `Assets__c` and their fields                                                                                                                                                                                                                    |

Not yet deployed or compiled against the org. Follow [MIGRATION_CUSTOM_OBJECTS.md](MIGRATION_CUSTOM_OBJECTS.md).

---

## 2026-10-01 — Round 2: LINE leads, conversion, templates, maintenance, history

### What's different for users

- **A new LINE friend becomes a Lead, not an Account.** When someone adds the NORITZ LINE account or messages it for the first time, a Lead appears, named after their LINE display name, with Lead Source **LINE**. Existing customers still land on their Account.
- **The LINE chat is on the Lead, Account and Case pages.** On a Case it shows the conversation of the Case's account. Messages sent from a Case are tagged with that Case.
- **Templates button above the chat box.** It offers five ready-made messages, and picking one fills in the customer's name. Admins edit them in Setup → Custom Metadata Types → LINE Chat Template → Manage Records.
- **Leads have their own Send Stripe Checkout Link and Simulate Payment Success buttons.**
  - The Lead needs a **Subscription Plan** first.
  - Sending the link gives the Lead a mock subscription id and moves it to _Working - Contacted_.
  - The first successful payment **converts the Lead** into a Person Account with an active contract, a payment record and the whole chat history. The page then opens the new customer.
- **Customer History card** on the Lead, Account and Case pages. It shows products (with filter health), contracts (green/red status badge) and payments (failed payments in **bold red** with the reason). It updates live.
- **Filter replacement reminders on LINE.**
  - A **Send Filter Reminder** button on the Asset sends one now.
  - The **Filter Reminder Daily** flow sends them automatically every morning (09:00 Bangkok) when a filter is due in 7 days. It never sends twice within 30 days.
- **Reset Demo also resets leads.**
  - A customer converted from a LINE lead is renamed "Archived - …", and a fresh Lead with the same LINE account and plan takes its place, so the conversion can be shown again.
  - Open LINE leads go back to _Open - Not Contacted_ with a clean chat.
- **Reset Demo no longer sends Somchai two "payment received" LINE messages.** A teammate's new Payment Success flow was sending one for each seeded payment.

### Fixes

- The teammate's Payment Success flow made 3 existing tests fail, because they had no stand-in for the LINE call. Added a shared test stand-in, `LineCalloutMock`.
- Removed leftover `System.debug` lines from `SendPaymentRetryAction` and `SendPaymentSuccessAction`, and a commented-out line in `SendCheckoutLinkAction`.
- Dates in the filter reminder are built from the ISO date. For a user with the Thai (th_TH) locale, `Date.year()` returns the Buddhist year (2569) and `Date.newInstance(2026, …)` reads 2026 as a Buddhist year.
- The plan → price table had three copies. It now lives in one place, `SubscriptionPlans.priceOf`.

### Metadata

| Area              | Added / changed                                                                                                                                                                                                                                                                                                        |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fields            | `LINE_Message__c.Lead__c`, `LINE_Message__c.Case__c`, new **Filter Reminder** message type; `Lead.Subscription_Plan__c`, `Lead.Stripe_Sub_ID__c`; `Account.Converted_From_LINE_Lead__c`; `Asset.Last_Filter_Reminder__c`; Lead Source value **LINE**                                                                   |
| Custom metadata   | `LINE_Chat_Template__mdt` (Body, Sort Order, Applies To) and 5 records                                                                                                                                                                                                                                                 |
| Apex (new)        | `LeadConversionService`, `SendFilterReminderAction`, `CustomerHistoryController`, `SubscriptionPlans`, `LineCalloutMock` (test), and tests for each                                                                                                                                                                    |
| Apex (changed)    | `LineWebhookHandler` (Leads), `LineMessagingService` (`Recipient`, `recipientFor`), `NoritzLineChatController` (any record, templates), `SendCheckoutLinkAction` (Leads), `SimulatePaymentSuccessAction` (Leads), `DemoResetAction`, `SendPaymentSuccessAction` (`suppress`), `LineMessageTrigger` (refresh for Leads) |
| LWC               | `noritzLineChat` (Lead/Case targets, Templates menu), `noritzCustomerHistory` (new), `noritzSendFilterReminder` (new), `noritzSendCheckoutLink` and `noritzSimulatePaymentSuccess` (Leads)                                                                                                                             |
| Flows             | `Filter_Reminder_Daily` (new, scheduled)                                                                                                                                                                                                                                                                               |
| Pages             | `Lead_Record_Page` (chat and history), `Account_Record_Page` (history), `Case_Record_Page` (new, activated as the Case default)                                                                                                                                                                                        |
| Actions & layouts | `Lead.Send_Checkout_Link`, `Lead.Simulate_Payment_Success`, `Asset.Send_Filter_Reminder`; Lead and Asset layouts                                                                                                                                                                                                       |
| Permission sets   | `LINE_Chat_User` (new classes and fields), `LINE_Webhook_Guest` (`LINE_Message__c.Lead__c`)                                                                                                                                                                                                                            |

Apex tests: **54 pass**. Every new class is covered at 90% or more.

Commits: `db02f54` (sync teammate changes) → `92a8488` → `329e884` → `754c225` → `dcadbc9` → `a294f10` → `a1ccbe2`.

---

## 2026-09-22 → 2026-09-30 — Round 1

- **2026-09-23:** LINE chat widget on the Account page, connected to a real LINE OA (send and receive), with live refresh. Scenario 1 (checkout link) and Scenario 2 (payment failure recovery).
- **2026-09-24:** New LINE friends automatically became Prospect Person Accounts, named after their LINE display name. Messages address the customer by name.
- **2026-09-25:**
  - Reset Demo button.
  - The reset covers every LINE-linked customer.
  - Automated messages switched to English.
  - Checkout and retry URLs shown as plain links.
- **2026-09-30 (teammate):** Simulate Payment Success button and Payment Success flow ("payment received" message); `Lead__c` on Asset and Payment History.

See [IMPLEMENTATION_PLAN.md](../IMPLEMENTATION_PLAN.md) for the round-1 details and decisions log.
