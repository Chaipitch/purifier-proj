# NORITZ Demo — Requirements

What the demo has to do, how each requirement was interpreted, and where it stands.
Source documents: the client spec (_NORITZ Thailand – B2C Water Purifier Subscription System_), [CLAUDE.md](../CLAUDE.md) and the team's round-2 notes.

Status: ✅ built and tested · ⏸ deferred · ❓ open question

---

## Round 1 — core demo (from the client spec)

| #   | Requirement                                                                               | How it was built                                                                                                                                                                           | Status |
| --- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ |
| R1  | Live LINE chat in Salesforce                                                              | Custom chat widget (`noritzLineChat`) connected to a real LINE Official Account: messages sent from Salesforce arrive in LINE, and replies show up live                                    | ✅     |
| R2  | Scenario 1: send a Stripe checkout link over LINE in one click                            | **Send Stripe Checkout Link** button on the Contract (later also on the Lead). Link is an obvious mock: `https://checkout.stripe.com/demo/<sub id>`                                        | ✅     |
| R3  | Scenario 2: payment failure → contract "Payment Failed", customer contacted automatically | Record-triggered flow on a failed `Payment_History__c`: Contract → Payment Failed, Account → Payment Suspended, retry link sent on LINE. **Simulate Payment Failure** button to trigger it | ✅     |
| R4  | Repeatable demo                                                                           | **Reset Demo** button on the Contract page (and `scripts/apex/reset_demo.apex`)                                                                                                            | ✅     |
| R5  | Contract status Pending Payment / Active / Payment Failed                                 | Standard `Contract.Status`, with Payment Failed in the Activated category (no custom status field)                                                                                         | ✅     |
| R6  | Header with coloured status badge                                                         | Not built as a custom header. The new Customer History card shows a green/red contract badge (R13)                                                                                         | ⏸      |
| R7  | Failed payments in bold red                                                               | Done in the Customer History card (R13)                                                                                                                                                    | ✅     |
| R8  | NORITZ Lightning Service Console app                                                      | Demo runs in the standard Service Console app                                                                                                                                              | ⏸      |
| R9  | Stripe webhook endpoint (Postman trigger)                                                 | Not built. The Simulate buttons cover the same beats                                                                                                                                       | ⏸      |

## Round 2 — team notes (2026-10-01)

The notes, with the decision taken for each one where it could be read more than one way:

| #   | Note                                                          | Decision                                                                                                                                                                                                                                                                                      | Status |
| --- | ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| R10 | "Template for chat"                                           | A **Templates** button above the chat's message box. It lists prompt variations; picking one fills the box for the agent to edit and send. Templates are custom metadata (`LINE Chat Template`), so admins edit them in Setup without a deploy. `{Name}` is replaced with the customer's name | ✅     |
| R11 | "First chat → Lead"                                           | A LINE user with no Account and no open Lead becomes a **Lead** (named after their LINE display name, Lead Source = LINE, Company blank). Existing customers still match their Account first                                                                                                  | ✅     |
| R12 | "Once Lead has contract → convert to Account, Contact"        | Convert on the **first successful payment**. A contract can only belong to an Account, so the payment, the conversion and the contract happen together. The Lead becomes a **Person Account**, which is an Account and a Contact in one                                                       | ✅     |
| R13 | "History tracking – query Asset (product), contract, payment" | A **Customer History** card listing the customer's products, contracts and payments, refreshed live                                                                                                                                                                                           | ✅     |
| R14 | "Apex invocable for maintenance"                              | **Send filter replacement reminder on LINE** invocable action, used by a daily scheduled flow (filter due in 7 days) and by a **Send Filter Reminder** button on the Asset                                                                                                                    | ✅     |
| R15 | "LINE chat placement: Lead, acc, case"                        | The chat is on the Lead, Account and Case pages. A Case shows its Account's conversation                                                                                                                                                                                                      | ✅     |
| R16 | "Redesign obj, relink obj"                                    | `LINE_Message__c` gets Lead and Case links. On conversion, the Lead's messages and assets move to the new Account, and the first payment keeps a link to the Lead                                                                                                                             | ✅     |

## Constraints

- Salesforce Developer Edition, for demo and PoC only. Never a production org.
- Everything payment-related is mocked. Links contain `/demo/`.
- Secrets (the LINE channel access token and channel secret) are entered in Setup only and never stored in source.
- The demo must be repeatable: one click resets it.
- Don't enable features that can't be undone, or delete fields or objects, without asking.

## Open questions

| #   | Question                                                                                          | Owner  |
| --- | ------------------------------------------------------------------------------------------------- | ------ |
| Q1  | Stripe or Krungsri? The spec names both. Mocked either way                                        | Client |
| Q2  | Should automated messages be English (current) or Thai?                                           | Team   |
| Q3  | Should the existing auto-created Prospect accounts (Meng, Chaipitch, terk.) be turned into Leads? | Team   |
| Q4  | Who should the daily reminder flow run as in a real org, so it has access to the LINE credential? | Admin  |
