trigger LineMessageTrigger on LINE_Message__c(after insert, after delete) {
  List<LINE_Message__c> changed = Trigger.isDelete ? Trigger.old : Trigger.new;

  // One refresh per customer record whose chat changed: the Account, or the Lead before conversion.
  // Account_Id__c carries either id.
  Set<Id> accountIds = new Set<Id>();
  for (LINE_Message__c m : changed) {
    if (m.Account__c != null) {
      accountIds.add(m.Account__c);
    }
    if (m.Lead__c != null) {
      accountIds.add(m.Lead__c);
    }
  }

  List<LINE_Chat_Refresh__e> events = new List<LINE_Chat_Refresh__e>();
  for (Id accountId : accountIds) {
    events.add(new LINE_Chat_Refresh__e(Account_Id__c = accountId));
  }
  if (!events.isEmpty()) {
    EventBus.publish(events);
  }

  // New messages from the customer ring the owner's notification bell (see LineInboundNotifications).
  if (Trigger.isInsert) {
    List<LINE_Inbound_Message__e> inbound = new List<LINE_Inbound_Message__e>();
    for (LINE_Message__c m : changed) {
      if (
        m.Direction__c == 'Inbound' &&
        (m.Account__c != null ||
        m.Lead__c != null)
      ) {
        inbound.add(new LINE_Inbound_Message__e(Message_Id__c = m.Id));
      }
    }
    if (!inbound.isEmpty()) {
      EventBus.publish(inbound);
    }
  }
}
