# NORITZ Demo — Handoff

Everything the next person needs to run, change and support the demo. For a click-by-click demo script see [TESTING.md](TESTING.md). For what changed and why, see [CHANGES.md](CHANGES.md) and [REQUIREMENTS.md](REQUIREMENTS.md).

---

## 1. Where things are

| What             | Where                                                                                                                                        |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Salesforce org   | Developer Edition, CLI alias `noritz`: `https://orgfarm-28f7eccd9f-dev-ed.develop.my.salesforce.com`                                         |
| App              | App Launcher → **Service Console**                                                                                                           |
| Demo customer    | **Somchai Sukhumvit**, Premium contract `sub_demo_12345` (custom `Contracts__c`; Reset Demo creates it if missing)                           |
| LINE webhook URL | `https://orgfarm-28f7eccd9f-dev-ed.develop.my.salesforce-sites.com/line/services/apexrest/line/webhook`                                      |
| Source           | `force-app/main/default` (SFDX). Git remotes: `origin` → github.com/wchaipitch-ts/noritz-ts, `purifier` → github.com/Chaipitch/purifier-proj |
| Docs             | `docs/` (this folder) and `IMPLEMENTATION_PLAN.md` (round-1 tracker, run-book and decisions)                                                 |

## 2. How it works

```
LINE app ──► LINE platform ──► Salesforce Site (guest) ──► LineWebhookHandler
                                                            │ checks X-Line-Signature
                                                            │ Account by LINE id? ─► message on Account
                                                            │ else open Lead?     ─► message on Lead
                                                            │ else create Lead    ─► message on Lead
                                                            ▼
                                     LINE_Message__c ──► LineMessageTrigger ──► LINE_Chat_Refresh__e
                                                                                 │
                       noritzLineChat / noritzCustomerHistory (empApi) ◄─────────┘ reload live

Agent / flow ──► LineMessagingService.pushAndInsert ──► LINE Messaging API (push) ──► LINE app
                 (push first, then save: Apex forbids a callout after DML)
```

**Customer lifecycle**

1. A new LINE friend becomes a **Lead** (Lead Source LINE, Company blank).
2. The agent sets the **Subscription Plan**, then clicks **Send Stripe Checkout Link**. The Lead gets `sub_demo_xxxxxx` and moves to Working - Contacted.
3. The agent clicks **Simulate Payment Success**, which runs `LeadConversionService.convertOnFirstPayment`:
   - converts the Lead to a **Person Account** (Converted From LINE Lead = true)
   - creates a Pending Payment contract
   - moves the chat and assets to the Account
   - inserts a successful payment. The teammate's **Payment Success Recovery** flow then activates the contract, sets the customer Active and sends "payment received" on LINE.
4. Later, a failed payment triggers **Payment Failure Recovery**: Contract → Payment Failed, Account → Payment Suspended, and a retry link goes out on LINE.
5. Maintenance: **Filter Reminder Daily** (09:00 Bangkok) and the **Send Filter Reminder** button on the Asset send the filter-due message.

**Which record a chat belongs to:** `LineMessagingService.recipientFor(recordId)`:

- Lead: its own chat, or the Account it converted to.
- Account: its own chat.
- Case: its Account's chat.

The chat controller, the history card and the checkout action all use it.

## 3. Components

| Piece                        | Files                                                                                                                                                                                                                 |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Chat widget                  | `lwc/noritzLineChat`, `classes/NoritzLineChatController`                                                                                                                                                              |
| Chat templates               | `objects/LINE_Chat_Template__mdt`, `customMetadata/LINE_Chat_Template.*`                                                                                                                                              |
| Inbound LINE                 | `classes/LineWebhookHandler`, Site `line_webhook`, permission set `LINE_Webhook_Guest`                                                                                                                                |
| Outbound LINE                | `classes/LineMessagingService`, Named Credential `LINE_Messaging_API`, External Credential `LINE_Messaging`                                                                                                           |
| Checkout link                | `classes/SendCheckoutLinkAction`, `lwc/noritzSendCheckoutLink`, actions `Contracts__c.Send_Checkout_Link`, `Lead.Send_Checkout_Link`                                                                                  |
| Payment success / conversion | `classes/SimulatePaymentSuccessAction`, `classes/LeadConversionService`, `classes/SendPaymentSuccessAction`, flow `Payment_Success_Recovery`, `lwc/noritzSimulatePaymentSuccess`                                      |
| Payment failure              | `classes/SimulatePaymentFailureAction`, `classes/SendPaymentRetryAction`, flow `Payment_Failure_Recovery`                                                                                                             |
| Maintenance reminder         | `classes/SendFilterReminderAction`, flow `Filter_Reminder_Daily`, `lwc/noritzSendFilterReminder`, action `Assets__c.Send_Filter_Reminder`                                                                             |
| Customer history             | `lwc/noritzCustomerHistory`, `classes/CustomerHistoryController`                                                                                                                                                      |
| Reset                        | `classes/DemoResetAction`, `lwc/noritzResetDemo`, actions `Lead.Reset_Demo`, `Account.Reset_Demo`, `Contracts__c.Reset_Demo`, `scripts/apex/reset_demo.apex`, one-time `scripts/apex/cleanup_archived_customers.apex` |
| Prices                       | `classes/SubscriptionPlans` (Standard 900, Premium 1,500)                                                                                                                                                             |
| Pages                        | `flexipages/Account_Record_Page`, `Lead_Record_Page`, `Case_Record_Page`, `NORITZ_Contract_Record_Page`, `NORITZ_Asset_Record_Page`                                                                                   |

## 4. Access

- **Agents** need the **LINE Chat User** permission set. It grants the Apex classes, `LINE_Message__c`, the new fields and the LINE credential. Anyone without it gets "insufficient access" in the chat.
- **The Site guest user** has **LINE Webhook Guest**: only the webhook class, message create, the LINE credential (for the display-name lookup) and the custom setting. Its queries and DML run in system mode, and only after the signature check passes.

## 5. Configuration (Setup only, never in source)

| Setting                   | Where                                                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| LINE channel access token | Setup → Named Credentials → External Credentials → **LINE Messaging** → principal **LINE_Bot** → parameter `token` (lowercase) |
| LINE channel secret       | Setup → Custom Settings → **LINE Settings** → Manage → org default                                                             |
| Chat templates            | Setup → Custom Metadata Types → **LINE Chat Template** → Manage Records                                                        |
| Reminder schedule         | Setup → Flows → **Filter Reminder Daily**                                                                                      |

**Switching to another LINE Official Account:**

1. Update the token and secret above.
2. In LINE Developers, paste the webhook URL, press **Verify** and turn **Use webhook** on.
3. In LINE OA Manager, turn auto-response off.

LINE user ids differ per OA, so everyone becomes a new Lead on the new OA. To keep demoing as Somchai, copy your new LINE User ID onto Somchai and delete the Lead it created.

## 6. Deploy

```bash
sf project deploy start --source-dir force-app/main/default/<path> --target-org noritz --test-level RunLocalTests
```

- **Don't deploy `externalCredentials/`.** Redeploying it can wipe the token.
- **Retrieve first.** Teammates edit pages and layouts in the org, so retrieve before editing (`sf project retrieve start -m FlexiPage:Account_Record_Page`), then deploy only the files you changed.
- **Reload twice after deploying an LWC.** The first load can still use the old version.

## 7. Gotchas

- **Thai locale and AD years:**
  - Standard Salesforce pages show Buddhist years (2569) to users whose **Locale** is Thai (th_TH). `scripts/apex/use_gregorian_locale.apex` moves them to English (United Kingdom), which keeps AD years; their language is unchanged. Set Setup → Company Information → **Locale** the same way so new users get it.
  - In Apex, for a th_TH user, `Date.year()` returns 2569, and `Date.newInstance(2026, …)` and `toStartOfMonth()` save the wrong year. Use `GregorianDates` (`startOfMonth`, `addMonths`, `format`), `addDays`, `Date.valueOf('yyyy-MM-dd')` and `String.valueOf(date)`.
  - The LWCs format dates with `en-GB` and `calendar: "gregory"`, so they always show AD.
- **Contracts and assets are custom objects** (`Contracts__c`, `Assets__c`), not standard Contract and Asset. Their status moves freely, and an asset can belong to a Lead only. See [MIGRATION_CUSTOM_OBJECTS.md](MIGRATION_CUSTOM_OBJECTS.md).
- **A conversion can't be undone,** so the reset deletes converted customers (with their contracts, payments, products and chat) and creates a fresh Lead with the same LINE account in their place. If Salesforce refuses to delete one, it is archived ("Archived - <name>", LINE id cleared) instead.
- **Seeding payments in Apex fires flows.** A successful payment fires the Payment Success flow, which messages the customer. Set `SendPaymentSuccessAction.suppress = true` while seeding (the reset does).
- **Callouts in tests** need `Test.setMock(HttpCalloutMock.class, new LineCalloutMock())`, including tests that insert payments, because the flows message LINE.
- **The daily reminder flow** runs in the background, not as the agent. It has not been tested live yet. If its reminders come back "Not delivered" with an authorization error, the running user has no access to the LINE credential. Give that user the **LINE Chat User** permission set. The Asset button always runs as the agent who clicks it.

## 8. Open items

- Header with coloured badge, NORITZ console app, Stripe webhook endpoint: deferred (see [REQUIREMENTS.md](REQUIREMENTS.md)).
- The auto-created Prospect accounts from before round 2 (Meng, Chaipitch, terk.) are still Accounts.
- **Backup screen recording** of a full run: still to do.
- The BA handover page (claude.ai artifact) describes round 1. Update it once the round-2 flow has been rehearsed.
