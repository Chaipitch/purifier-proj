# Moving to the custom Contract and Asset objects

The consultant replaced standard **Contract** and **Asset** with two custom objects, `Contracts__c` and `Assets__c`. This branch (`custom-contract-asset-objects`) points every class, flow, action, page and test at them. Some steps can only be done in the org, and they have to happen in the order below.

> Nothing on this branch has been deployed or compiled against the org yet. The deploy in step 4 is also the first real check.

---

## Why this order

The old `Payment_History__c.Contract__c` is a required master-detail field pointing at **standard** Contract. Salesforce can't re-point a relationship field, and it won't delete a field that Apex classes or flows still reference. So:

1. the new code goes in first, with a **new** master-detail field, `Subscription_Contract__c` (label "Contract"), pointing at `Contracts__c`
2. the old field is deleted afterwards, once nothing references it.

Between steps 4 and 6 the demo doesn't work: payments can't be saved while both master-detail fields exist. Plan for about 15 minutes.

## 1. Check the consultant's objects match what the code expects

```bash
sf project retrieve start -m CustomObject:Contracts__c CustomObject:Assets__c --target-org noritz
```

The code assumes these API names, all taken from the spreadsheet:

| Object         | Fields used                                                                                                                                                                                                 |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Contracts__c` | `Name` (auto number), `Account__c`, `Lead__c`, `Status__c`, `Subscription_Plan__c`, `Stripe_Sub_ID__c`, `Next_Billing_Date__c`, `Contract_Start_Date__c`, `Contract_End_Date__c`, `Contract_Term_months__c` |
| `Assets__c`    | `Name`, `Account__c`, `Lead__c`, `Serial_Number__c`, `Next_Filter_Replacement__c`, `Filter_Status_Icon__c`, `Install_Date__c`, `Status__c`, `Product__c` (relationship `Product__r`)                        |

Check these too:

- **`Contracts__c.Status__c` values** are exactly `Pending Payment`, `Active` and `Payment Failed`.
- **`Contracts__c.Subscription_Plan__c` values** are exactly `Standard (900 THB)` and `Premium (1,500 THB)`, the same as on Lead. `SubscriptionPlans.priceOf` looks prices up by these labels.
- **`Assets__c.Status__c`** has `Installed`.
- **`Contract_End_Date__c` is a plain Date field.** The code writes to it. If it's a formula, remove the two `Contract_End_Date__c =` lines in `DemoResetAction` and `LeadConversionService`.
- **None of the lookups or picklists is marked required.** The `LINE Chat User` permission set grants field access to them, and Salesforce refuses field access settings on required fields.
- **The `Lead__c` lookups have their own relationship names.** Standard Contract and Asset already use `Contracts__r` and `Assets__r` on Lead.
- **`Filter_Status_Icon__c` exists** on `Assets__c`, rebuilt from the old Asset formula.

If an API name differs, a find-and-replace across `force-app/` fixes it.

## 2. Pull the branch and retrieve what teammates may have changed

```bash
git fetch origin custom-contract-asset-objects && git checkout custom-contract-asset-objects
sf project retrieve start --target-org noritz --output-dir ../org-copy \
  -m "FlexiPage:Account_Record_Page" -m "FlexiPage:Lead_Record_Page" \
  -m "Layout:Lead-Lead Layout" -m "Layout:Contract-Contract Layout" -m "Layout:Asset-Asset Layout"
git diff --no-index ../org-copy force-app/main/default --stat
```

Teammates edit pages and layouts in the org. If the org copy of `Account_Record_Page`, `Lead_Record_Page` or the Lead, Contract or Asset layout differs from the repo, remove it from `manifest/custom-objects-migration.xml`. Then make the same change by hand after step 4 (see "Pages and layouts" below).

## 3. Empty Payment History

A new master-detail field can only be added while the object has no records, including records in the recycle bin. This deletes demo payments only; Reset Demo re-creates them in step 7.

```bash
sf apex run --target-org noritz <<< "List<Payment_History__c> p = [SELECT Id FROM Payment_History__c]; delete p; if (!p.isEmpty()) Database.emptyRecycleBin(p);"
```

## 4. Deploy everything in one go

```bash
sf project deploy start --target-org noritz \
  --manifest manifest/custom-objects-migration.xml \
  --test-level NoTestRun
```

- **`NoTestRun` is deliberate.** The tests can't pass until the old required field is gone (step 6), and a Developer Edition org doesn't require tests on deploy. They run in step 6.
- **It creates the two new fields:**
  - `Payment_History__c.Subscription_Contract__c` (second master-detail, relationship order 1)
  - `Assets__c.Last_Filter_Reminder__c`
- **It updates** the classes, the three flows, the quick actions, the history card, the Status path, the pages, the layouts and the LINE Chat User permission set.
- **If it fails on a field name**, the consultant's object doesn't match step 1. Fix the name with a find-and-replace across `force-app/` and run it again. The deploy is all-or-nothing, so a failure leaves the org as it was.
- **As before, don't deploy `externalCredentials/`.**

## 5. Remove the old flow versions

Deploying the flows activated new versions of **Payment Failure Recovery** and **Payment Success Recovery**. Their older versions still reference the old field, and they block its deletion.

Setup → Flows → each flow → **View Details and Versions** → delete every **inactive** version.

## 6. Delete the old field, then run the tests

1. Setup → Object Manager → **Payment History** → Fields → **Contract** (`Contract__c`, pointing at Contract) → **Where is this used?**
   - The list should be empty.
   - If it shows a roll-up summary, validation rule or report type, remove that reference first.
2. **Delete** the field. `Subscription_Contract__c` becomes the only master-detail field.
3. Optional: Payment History → **Deleted Fields** → **Erase** `Contract__c`.
4. Run the tests:
   ```bash
   sf apex run test --target-org noritz --test-level RunLocalTests --wait 20 --result-format human
   ```

## 7. Finish in Setup

1. **Activate the record pages.** In App Builder, open **NORITZ Contract Record Page** and **NORITZ Asset Record Page** and click Activation → **Org Default**.
   - The contract page has the Send Stripe Checkout Link, Simulate Payment Failure, Simulate Payment Success and Reset Demo buttons, plus the Status path.
   - The asset page has Send Filter Reminder.
2. **Console navigation.** In the Service Console app, replace Contracts and Assets with the custom object tabs. If the consultant hasn't created tabs yet, create them in Setup → Tabs.
3. **Run Reset Demo.** In a fresh org there's no custom contract yet, and so no Reset Demo button to click. Run it from the CLI:
   ```bash
   sf apex run --target-org noritz --file scripts/apex/reset_demo.apex
   ```
   This creates Somchai's Premium contract (`sub_demo_12345`) and his NORITZ Pure Water X1 (`NZ-2026-9981`, filter due in 14 days). After that, the button on his contract restores them on every run.
4. **Smoke test.** Open Somchai's contract, then:
   - **Send Stripe Checkout Link** → the link appears in the chat
   - **Simulate Payment Failure** → contract Payment Failed, customer Payment Suspended, retry message in the chat, a bold red payment on the history card
   - **Reset Demo**.
5. **Optional extras:**
   - Add related lists for the new objects on the Account and Lead pages. The old Assets and Contracts lists were removed because the Customer History card already shows products, contracts and payments.
   - Delete the old quick actions `Contract.Send_Checkout_Link`, `Contract.Simulate_Payment_Failure`, `Contract.Simulate_Payment_Success`, `Contract.Reset_Demo` and `Asset.Send_Filter_Reminder`. They're no longer on any layout, and they'd fail if clicked.

## Pages and layouts changed on this branch

| File                          | Change                                                                          |
| ----------------------------- | ------------------------------------------------------------------------------- |
| `Account_Record_Page`         | Removed the standard Assets and Contracts related lists                         |
| `Lead_Record_Page`            | Removed the standard Assets and Contracts related lists                         |
| `Lead-Lead Layout`            | Related lists now `Assets__c.Lead__c` and `Contracts__c.Lead__c`                |
| `Contract-Contract Layout`    | Removed the four demo buttons and the Payment History related list              |
| `Asset-Asset Layout`          | Removed Send Filter Reminder (moved to the custom asset)                        |
| `NORITZ_Contract_Record_Page` | New: highlights with the four demo buttons, Status path, details, related lists |
| `NORITZ_Asset_Record_Page`    | New: highlights with Send Filter Reminder, details, related lists               |
