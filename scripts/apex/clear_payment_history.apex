// Migration step 3 (docs/MIGRATION_CUSTOM_OBJECTS.md): empties Payment History, recycle bin
// included, so the new Subscription_Contract__c master-detail field can be added. Demo payments
// only; Reset Demo re-creates them.
// sf apex run --target-org noritz --file scripts/apex/clear_payment_history.apex
List<Payment_History__c> payments = [SELECT Id FROM Payment_History__c];
delete payments;
if (!payments.isEmpty()) {
  Database.emptyRecycleBin(payments);
}
System.debug(LoggingLevel.WARN, payments.size() + ' payment(s) deleted.');
