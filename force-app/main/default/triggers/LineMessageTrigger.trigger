trigger LineMessageTrigger on LINE_Message__c(after insert, after delete) {
  List<LINE_Message__c> changed = Trigger.isDelete ? Trigger.old : Trigger.new;

  Set<Id> accountIds = new Set<Id>();
  for (LINE_Message__c m : changed) {
    if (m.Account__c != null) {
      accountIds.add(m.Account__c);
    }
  }

  List<LINE_Chat_Refresh__e> events = new List<LINE_Chat_Refresh__e>();
  for (Id accountId : accountIds) {
    events.add(new LINE_Chat_Refresh__e(Account_Id__c = accountId));
  }
  if (!events.isEmpty()) {
    EventBus.publish(events);
  }
}
