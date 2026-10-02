// Diagnostic, changes nothing: prints the picklist values the code depends on and checks that a
// Lead keeps its Subscription Plan when saved (the test lead is rolled back).
// sf apex run --target-org noritz --file scripts/apex/check_org_values.apex | Select-String "CHECK"
Map<String, Schema.DescribeFieldResult> fields = new Map<String, Schema.DescribeFieldResult>{
  'Contracts__c.Status__c' => Schema.SObjectType.Contracts__c.fields.Status__c,
  'Contracts__c.Subscription_Plan__c' => Schema.SObjectType.Contracts__c.fields.Subscription_Plan__c,
  'Assets__c.Status__c' => Schema.SObjectType.Assets__c.fields.Status__c,
  'Lead.Subscription_Plan__c' => Schema.SObjectType.Lead.fields.Subscription_Plan__c
};
for (String name : fields.keySet()) {
  Schema.DescribeFieldResult f = fields.get(name);
  System.debug(LoggingLevel.WARN, 'CHECK ' + name + ' type=' + f.getType() + ' restricted=' + f.isRestrictedPicklist());
  for (Schema.PicklistEntry e : f.getPicklistValues()) {
    System.debug(LoggingLevel.WARN, 'CHECK   API name [' + e.getValue() + '] label [' + e.getLabel() + '] active=' + e.isActive());
  }
}

Savepoint sp = Database.setSavepoint();
Lead l = new Lead(LastName = 'Plan check', Subscription_Plan__c = 'Standard (900 THB)');
insert l;
Lead saved = [SELECT Subscription_Plan__c, Status FROM Lead WHERE Id = :l.Id];
System.debug(LoggingLevel.WARN, 'CHECK Lead saved with plan [Standard (900 THB)], read back [' + saved.Subscription_Plan__c + '], status [' + saved.Status + ']');
Database.rollback(sp);
