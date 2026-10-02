# Moving to the custom Contract and Asset objects

The consultant replaced standard **Contract** and **Asset** with two custom objects, `Contracts__c` and `Assets__c`. This branch (`custom-contract-asset-objects`) points every class, flow, action, page and test at them. Some steps can only be done in the org, and they have to happen in the order below. Otherwise the deploy fails.

> Nothing on this branch has been deployed or compiled against the org yet. The first deploy (step 3) is also the first real check.

---

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

## 2. Remove the old payment link

`Payment_History__c.Contract__c` is a required master-detail field pointing at **standard** Contract, and Salesforce can't change what a relationship field points to. So the field has to be replaced. These steps delete demo payment records only. The reset re-creates them.

1. Delete every payment record:
   ```bash
   sf apex run --target-org noritz <<< "delete [SELECT Id FROM Payment_History__c];"
   ```
2. Setup → Object Manager → **Payment History** → Fields → **Contract**.
   - If there are roll-up summary fields on Contract that use it, delete them first.
   - Click **Edit** → **Change Field Type** → **Lookup Relationship**, then save.
   - Delete the field.
3. Setup → Object Manager → **Payment History** → **Deleted Fields** → **Erase** `Contract__c`. The API name stays reserved until the field is erased.

## 3. Deploy the new fields first

```bash
sf project deploy start --target-org noritz \
  -d force-app/main/default/objects/Payment_History__c/fields/Contract__c.field-meta.xml \
  -d force-app/main/default/objects/Assets__c/fields/Last_Filter_Reminder__c.field-meta.xml
```

- **`Payment_History__c.Contract__c`:** a new required master-detail field pointing at `Contracts__c`, with relationship `Payment_History__r`. It only deploys while Payment History has no records.
- **`Assets__c.Last_Filter_Reminder__c`:** the daily reminder uses it so it never sends twice within 30 days. It wasn't in the consultant's list.

## 4. Deploy everything else and run the tests

**Retrieve first.** Teammates edit pages and layouts in the org. If the org copies of `Account_Record_Page`, `Lead_Record_Page`, or the Lead, Contract and Asset layouts differ from the repo, don't deploy those files. Make the same change in App Builder or the layout editor instead (see "Pages and layouts" below).

```bash
sf project deploy start --target-org noritz --test-level RunLocalTests \
  -d force-app/main/default/classes \
  -d force-app/main/default/flows \
  -d force-app/main/default/quickActions \
  -d force-app/main/default/lwc/noritzCustomerHistory \
  -d force-app/main/default/pathAssistants \
  -d force-app/main/default/flexipages \
  -d force-app/main/default/layouts \
  -d force-app/main/default/permissionsets/LINE_Chat_User.permissionset-meta.xml
```

As before, don't deploy `externalCredentials/`.

## 5. Finish in Setup

1. **Activate the record pages.** In App Builder, open **NORITZ Contract Record Page** and **NORITZ Asset Record Page** and click Activation → **Org Default**.
   - The contract page has the Send Stripe Checkout Link, Simulate Payment Failure, Simulate Payment Success and Reset Demo buttons, plus the Status path.
   - The asset page has Send Filter Reminder.
2. **Console navigation.** In the Service Console app, replace Contracts and Assets with the custom object tabs. If the consultant hasn't created tabs yet, create them in Setup → Tabs.
3. **Optional related lists** on the Account and Lead pages for the new objects. The old Assets and Contracts related lists were removed from both pages, because the Customer History card already shows products, contracts and payments.
4. **Run Reset Demo.** In a fresh org, it now **creates** Somchai's Premium contract (`sub_demo_12345`) and his NORITZ Pure Water X1 (`NZ-2026-9981`, filter due in 14 days). After that it restores them on every run.
5. **Optional clean-up.** The old quick actions `Contract.Send_Checkout_Link`, `Contract.Simulate_Payment_Failure`, `Contract.Simulate_Payment_Success`, `Contract.Reset_Demo` and `Asset.Send_Filter_Reminder` are no longer on any layout. Their Apex now expects custom-object ids, so they would fail if clicked. Delete them in Setup when convenient. The standard Contract and Asset records can stay.

## Pages and layouts changed on this branch

| File                          | Change                                                                          |
| ----------------------------- | ------------------------------------------------------------------------------- |
| `Account_Record_Page`         | Removed the standard Assets and Contracts related lists                         |
| `Lead_Record_Page`            | Removed the standard Assets and Contracts related lists                         |
| `Lead-Lead Layout`            | Related lists now `Assets__c.Lead__c` and `Contracts__c.Lead__c`                |
| `Contract-Contract Layout`    | Removed the four demo buttons (they moved to the custom contract)               |
| `Asset-Asset Layout`          | Removed Send Filter Reminder (moved to the custom asset)                        |
| `NORITZ_Contract_Record_Page` | New: highlights with the four demo buttons, Status path, details, related lists |
| `NORITZ_Asset_Record_Page`    | New: highlights with Send Filter Reminder, details, related lists               |
