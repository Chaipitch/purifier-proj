// One-time clean-up: deletes the "Archived - ..." customers that earlier versions of Reset Demo
// left behind, with their custom contracts (and payments), products, old standard assets and
// LINE chat. Reset Demo now deletes converted customers itself, so this only clears the backlog.
// An account Salesforce won't delete (for example one with an activated standard Contract) is
// reported and left as it is.
// sf apex run --target-org noritz --file scripts/apex/cleanup_archived_customers.apex | Select-String "CLEANUP"
List<Account> archived = [SELECT Id, Name FROM Account WHERE Name LIKE 'Archived - %'];
System.debug(LoggingLevel.WARN, 'CLEANUP Archived customers found: ' + archived.size());
if (!archived.isEmpty()) {
  delete [SELECT Id FROM Contracts__c WHERE Account__c IN :archived];
  delete [SELECT Id FROM Assets__c WHERE Account__c IN :archived];
  delete [SELECT Id FROM Asset WHERE AccountId IN :archived];
  delete [SELECT Id FROM LINE_Message__c WHERE Account__c IN :archived];
  List<Database.DeleteResult> results = Database.delete(archived, false);
  for (Integer i = 0; i < archived.size(); i++) {
    String outcome = results[i].isSuccess()
      ? 'deleted'
      : 'NOT deleted: ' + results[i].getErrors()[0].getMessage();
    System.debug(LoggingLevel.WARN, 'CLEANUP ' + archived[i].Name + ' - ' + outcome);
  }
}
