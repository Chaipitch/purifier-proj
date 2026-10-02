// Sends a bell notification to the owner of the Lead or Account when a customer's LINE message
// arrives. Clicking it opens that record, where the chat shows the message.
public without sharing class LineInboundNotifications {
  @TestVisible
  private static final String NOTIFICATION_TYPE = 'LINE_Inbound_Message';
  private static final Integer PREVIEW_LENGTH = 120;

  // Notifications sent, for tests (Messaging.CustomNotification has no other way to check).
  @TestVisible
  private static List<Messaging.CustomNotification> sent = new List<Messaging.CustomNotification>();

  public static void notifyOwners(Set<Id> messageIds) {
    if (messageIds == null || messageIds.isEmpty()) {
      return;
    }
    List<CustomNotificationType> types = [
      SELECT Id
      FROM CustomNotificationType
      WHERE DeveloperName = :NOTIFICATION_TYPE
      WITH SYSTEM_MODE
    ];
    if (types.isEmpty()) {
      return;
    }

    for (LINE_Message__c m : [
      SELECT
        Message_Body__c,
        Account__c,
        Account__r.Name,
        Account__r.OwnerId,
        Lead__c,
        Lead__r.Name,
        Lead__r.OwnerId
      FROM LINE_Message__c
      WHERE Id IN :messageIds AND Direction__c = 'Inbound'
      WITH SYSTEM_MODE
    ]) {
      Boolean onAccount = m.Account__c != null;
      Id recordId = onAccount ? m.Account__c : m.Lead__c;
      Id ownerId = onAccount ? m.Account__r.OwnerId : m.Lead__r.OwnerId;
      String name = onAccount ? m.Account__r.Name : m.Lead__r.Name;
      if (recordId == null || ownerId == null) {
        continue;
      }

      Messaging.CustomNotification notification = new Messaging.CustomNotification();
      notification.setNotificationTypeId(types[0].Id);
      notification.setTitle('New LINE message from ' + name);
      notification.setBody(preview(m.Message_Body__c));
      notification.setTargetId(recordId);
      try {
        notification.send(new Set<String>{ ownerId });
        sent.add(notification);
      } catch (Exception e) {
        // A missed notification must never lose the message; it's already saved.
        System.debug(
          LoggingLevel.WARN,
          'LINE notification not sent: ' + e.getMessage()
        );
      }
    }
  }

  private static String preview(String body) {
    String text = String.isBlank(body) ? '(no text)' : body.normalizeSpace();
    return text.abbreviate(PREVIEW_LENGTH);
  }
}
