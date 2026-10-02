// Diagnostic, changes nothing: prints the picklist values the code depends on, checks that a
// Lead keeps its Subscription Plan when saved (the test lead is rolled back), and lists the
// active record-triggered flows and Somchai's contract and asset.
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

// Every active record-triggered flow, with its object (a before-save flow can change fields as the
// record saves).
try {
  for (SObject f : Database.query(
    'SELECT ApiName, Label, TriggerType, TriggerObjectOrEventLabel, LastModifiedDate FROM FlowDefinitionView WHERE IsActive = TRUE AND TriggerType != NULL'
  )) {
    System.debug(LoggingLevel.WARN, 'CHECK Flow on [' + f.get('TriggerObjectOrEventLabel') + '] [' + f.get('Label') + '] api [' + f.get('ApiName') + '] runs [' + f.get('TriggerType') + '] last changed [' + f.get('LastModifiedDate') + ']');
  }
} catch (Exception e) {
  System.debug(LoggingLevel.WARN, 'CHECK Could not list flows: ' + e.getMessage() + '. Use Setup > Flow Trigger Explorer instead.');
}

// What the reset left for Somchai.
for (Contracts__c c : [SELECT Name, Status__c, Stripe_Sub_ID__c, Account__r.Name FROM Contracts__c WHERE Stripe_Sub_ID__c = 'sub_demo_12345']) {
  System.debug(LoggingLevel.WARN, 'CHECK Contract [' + c.Name + '] status [' + c.Status__c + '] customer [' + c.Account__r?.Name + ']');
}
List<Assets__c> purifiers = [SELECT Name, Serial_Number__c, Account__r.Name, Lead__c, Next_Filter_Replacement__c, LastModifiedDate FROM Assets__c WHERE Serial_Number__c = 'NZ-2026-9981'];
System.debug(LoggingLevel.WARN, 'CHECK Assets with serial NZ-2026-9981: ' + purifiers.size());
for (Assets__c a : purifiers) {
  System.debug(LoggingLevel.WARN, 'CHECK Asset [' + a.Name + '] customer [' + a.Account__r?.Name + '] lead [' + a.Lead__c + '] next filter [' + String.valueOf(a.Next_Filter_Replacement__c) + '] last changed [' + a.LastModifiedDate + ']');
}
