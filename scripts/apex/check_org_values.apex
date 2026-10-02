// Diagnostic, changes nothing: prints the picklist values the code depends on, checks that a
// Lead keeps its Subscription Plan when saved (the test lead is rolled back), and lists the
// record-triggered flows on Lead.
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

// Which record-triggered flows run on Lead (a before-save flow can blank fields as the record saves).
try {
  for (SObject f : Database.query(
    'SELECT ApiName, Label, TriggerType, TriggerObjectOrEventLabel, LastModifiedDate FROM FlowDefinitionView WHERE IsActive = TRUE AND TriggerType != NULL'
  )) {
    if (f.get('TriggerObjectOrEventLabel') == 'Lead') {
      System.debug(LoggingLevel.WARN, 'CHECK Lead flow [' + f.get('Label') + '] api [' + f.get('ApiName') + '] runs [' + f.get('TriggerType') + '] last changed [' + f.get('LastModifiedDate') + ']');
    }
  }
} catch (Exception e) {
  System.debug(LoggingLevel.WARN, 'CHECK Could not list flows: ' + e.getMessage() + '. Use Setup > Flow Trigger Explorer > Lead instead.');
}
