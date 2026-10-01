# NORITZ Demo — Testing

Two parts: the automated Apex tests, and a manual end-to-end run with a real phone. Run both after any change, and the manual run before every presentation.

---

## 1. Automated tests

```bash
sf apex run test --target-org noritz --test-level RunLocalTests --code-coverage --wait 20
```

Expected: **54 tests pass**, 0 fail.

| Test class                                                              | Covers                                                                                                                         |
| ----------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `LineWebhookHandlerTest`                                                | Signature check, new friend → Lead, Account wins over Lead, earlier messages attached, placeholder name and rename, redelivery |
| `NoritzLineChatControllerTest`                                          | Chat on Account, Lead and Case; send and failed send; validation; templates                                                    |
| `LineMessagingServiceTest`                                              | Name greeting, LINE unreachable                                                                                                |
| `SendCheckoutLinkActionTest`                                            | Contract and Lead checkout link, LINE rejection, not linked, missing plan or subscription                                      |
| `LeadConversionServiceTest`                                             | First payment converts the Lead (Person Account, contract, payment, chat moved), missing plan, already converted               |
| `SimulatePaymentFailureActionTest` / `SimulatePaymentSuccessActionTest` | Failure recovery flow, success payment at plan price                                                                           |
| `SendFilterReminderActionTest`                                          | Button and flow reminder, message text and date, missing date                                                                  |
| `CustomerHistoryControllerTest`                                         | History on Account, Case and new Lead                                                                                          |
| `DemoResetActionTest`                                                   | Somchai reset, LINE customers, converted lead comes back as a Lead, open lead trimmed, safe to run twice                       |

## 2. Before the manual run

1. Log in to the org (alias `noritz`) and open App Launcher → **Service Console**.
2. Check your user has the **LINE Chat User** permission set.
3. Open contract **00000101** (Somchai) and click **Reset Demo**. Expect a green "Demo reset" toast, then the page reloads.
4. On a phone, open the NORITZ LINE Official Account chat.
5. If anything was deployed today, reload the Salesforce page twice.

Record each step as ✅ / ❌ with a note.

## 3. Manual end-to-end steps

### A. A new LINE friend becomes a Lead

Use a LINE account that isn't linked to any Account or Lead yet (or block and re-add the OA).

| Step                                           | Expected                                                                                                                                |
| ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| A1. Add the NORITZ OA as a friend on the phone | Within a few seconds a **Lead** appears (Leads tab, Recently Viewed or search), named after the LINE display name, Lead Source **LINE** |
| A2. Open the Lead                              | The **LINE Chat** shows "[Added the OA as a friend]". **Customer History** says no products, contracts or payments yet                  |
| A3. Send "Hello" from the phone                | It appears in the Lead's chat within ~2 s, with no page refresh                                                                         |

### B. Chat and templates on the Lead

| Step                                                                    | Expected                                                                                        |
| ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| B1. Click **Templates** above the message box and pick **Plan options** | The message box fills with the plan text, addressed by the customer's name. Nothing is sent yet |
| B2. Edit the text if you like, press **Enter**                          | The message appears on the right (green) and arrives on the phone                               |
| B3. Press Shift+Enter in the box                                        | Adds a new line; doesn't send                                                                   |

### C. Checkout link from the Lead

| Step                                                                      | Expected                                                                                                                                                                                                              |
| ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| C1. Click **Send Stripe Checkout Link** before choosing a plan            | Error toast: "Choose a Subscription Plan on the lead first." Nothing is sent                                                                                                                                          |
| C2. Edit the Lead: Subscription Plan = **Premium (1,500 THB)**, then save | Saved                                                                                                                                                                                                                 |
| C3. Click **Send Stripe Checkout Link**                                   | Green toast "Checkout link sent". Phone gets "Hi …, Thank you for choosing NORITZ…" with `https://checkout.stripe.com/demo/sub_demo_xxxxxx`. The Lead's Status is **Working - Contacted** and Stripe Sub ID is filled |

### D. First payment converts the Lead

| Step                                                | Expected                                                                                                                                                                             |
| --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| D1. On the Lead, click **Simulate Payment Success** | Toast "Payment received: lead converted", and the page opens the new **Person Account**                                                                                              |
| D2. Look at the Account                             | Customer Status **Active**. LINE Chat has the whole conversation from the Lead. Customer History shows 1 contract with a green **Active** badge and 1 payment of THB 1,500 (Success) |
| D3. Look at the phone                               | "Thank you! We have successfully received the payment…" arrives (from the Payment Success flow)                                                                                      |
| D4. Send a message from the phone                   | It appears on the **Account's** chat, not on a Lead                                                                                                                                  |

### E. Payment failure on the new customer (or Somchai)

| Step                                                                 | Expected                                                                                                                                                                                                    |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| E1. Open the customer's contract, click **Simulate Payment Failure** | Orange toast. Contract Status → **Payment Failed** within ~2 s                                                                                                                                              |
| E2. Back on the Account                                              | Customer Status **Payment Suspended**. Customer History shows a **bold red** payment row with "Card Expired (ERR-02)" and a red **Payment Failed** badge, with no refresh. The chat shows the retry message |
| E3. Phone                                                            | Receives "Payment failed for your monthly subscription…" with the update-payment link                                                                                                                       |

### F. Filter reminder (maintenance)

| Step                                                                                           | Expected                                                                                                                                                                                    |
| ---------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| F1. Open Somchai's asset (NORITZ Pure Water X1). Make sure **Next Filter Date** is set         |                                                                                                                                                                                             |
| F2. Click **Send Filter Reminder**                                                             | Green toast. Phone gets "Hi Somchai, The filter on your NORITZ Pure Water X1 (…) is due for replacement on <date>. Reply here to book a technician visit." **Last Filter Reminder** = today |
| F3. Optional, the daily flow: set Next Filter Date to today + 7 and clear Last Filter Reminder | The next morning at 09:00 Bangkok the reminder arrives by itself. If it shows "Not delivered" in the chat, see HANDOFF.md §7                                                                |

### G. Chat on a Case

| Step                                                                 | Expected                                                                                                                          |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| G1. Create a Case for Somchai (Account = Somchai Sukhumvit), open it | The Case page shows **LINE Chat** with Somchai's conversation, and **Customer History** with his products, contracts and payments |
| G2. Send "We'll book your filter change" from the Case chat          | Arrives on the phone. The message is saved on Somchai's Account with the Case linked                                              |
| G3. Create a Case with no Account and open it                        | The chat says "This case isn't linked to a customer yet…" and has no Templates button                                             |

### H. Existing customer scenarios (Somchai)

| Step                                                  | Expected                                                                      |
| ----------------------------------------------------- | ----------------------------------------------------------------------------- |
| H1. Contract 00000101 → **Send Stripe Checkout Link** | Link arrives on the phone, shows in Somchai's chat                            |
| H2. Contract 00000101 → **Simulate Payment Failure**  | As in E                                                                       |
| H3. Contract 00000101 → **Simulate Payment Success**  | Contract back to **Active**, customer Active, "payment received" on the phone |

### I. Reset

| Step                                   | Expected                                                                                                                                                  |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| I1. Contract 00000101 → **Reset Demo** | Toast, then the page reloads. No LINE messages arrive on the phone                                                                                        |
| I2. Somchai                            | Active, 2 successful payments, 3 starting chat messages                                                                                                   |
| I3. The customer converted in D        | Renamed **Archived - <name>**, LINE User ID empty                                                                                                         |
| I4. Leads                              | A fresh Lead with the same name, LINE account and plan, Status **Open - Not Contacted**, chat showing only "[Added the OA as a friend]". Repeat C–D on it |
| I5. Click Reset Demo again             | Same result (safe to repeat)                                                                                                                              |

## 4. If a step fails

| Symptom                                      | Check                                                                                                                                                                   |
| -------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nothing arrives in Salesforce from the phone | LINE Developers: webhook URL set, **Use webhook** on, **Verify** succeeds. OA Manager: auto-response off. Channel secret in Setup matches the channel                   |
| "Not delivered" under a message              | Hover for LINE's error. A 401 means the channel access token is wrong. "Failed to send messages" (400) usually means the customer's LINE User ID is from a different OA |
| A new friend became an Account, not a Lead   | Their LINE User ID was already on an Account (Account wins). Clear it from that Account to test the Lead flow                                                           |
| Chat or history doesn't update live          | Reload the page. If it keeps happening, set the chat's **Polling interval** to 2 in App Builder                                                                         |
| Page shows old behaviour after a deploy      | Reload twice                                                                                                                                                            |
| Simulate Payment Success on a Lead fails     | The Lead needs a Subscription Plan, and must not be converted already                                                                                                   |
