// Runs as the Automated Process user, which can send notifications; the webhook's guest user can't.
trigger LineInboundNotificationTrigger on LINE_Inbound_Message__e(
  after insert
) {
  Set<Id> messageIds = new Set<Id>();
  for (LINE_Inbound_Message__e e : Trigger.new) {
    if (String.isNotBlank(e.Message_Id__c)) {
      messageIds.add(e.Message_Id__c);
    }
  }
  LineInboundNotifications.notifyOwners(messageIds);
}
