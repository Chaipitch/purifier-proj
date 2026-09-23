public with sharing class NoritzLineChatController {
  private static final Integer MAX_MESSAGES = 50;
  private static final Integer MAX_BODY_LENGTH = 4000;

  public class ChatData {
    @AuraEnabled
    public String customerName;
    @AuraEnabled
    public String lineUserId;
    @AuraEnabled
    public List<LINE_Message__c> messages;
  }

  // Not cacheable: the widget re-fetches after every refresh event and must not get a stale cached result.
  @AuraEnabled
  public static ChatData getChat(Id accountId) {
    Account acc = [
      SELECT Name, LINE_User_ID__c
      FROM Account
      WHERE Id = :accountId
    ];

    List<LINE_Message__c> newestFirst = [
      SELECT
        Id,
        Direction__c,
        Message_Body__c,
        Message_Type__c,
        Sent_At__c,
        Delivery_Status__c,
        Delivery_Error__c
      FROM LINE_Message__c
      WHERE Account__c = :accountId
      ORDER BY Sent_At__c DESC, Name DESC
      LIMIT :MAX_MESSAGES
    ];
    List<LINE_Message__c> oldestFirst = new List<LINE_Message__c>();
    for (Integer i = newestFirst.size() - 1; i >= 0; i--) {
      oldestFirst.add(newestFirst[i]);
    }

    ChatData data = new ChatData();
    data.customerName = acc.Name;
    data.lineUserId = acc.LINE_User_ID__c;
    data.messages = oldestFirst;
    return data;
  }

  @AuraEnabled
  public static LINE_Message__c sendMessage(Id accountId, String body) {
    String text = body == null ? '' : body.trim();
    if (String.isBlank(text)) {
      throw auraError('Type a message before sending.');
    }
    if (text.length() > MAX_BODY_LENGTH) {
      throw auraError(
        'Message is too long (maximum ' + MAX_BODY_LENGTH + ' characters).'
      );
    }

    Account acc = [SELECT LINE_User_ID__c FROM Account WHERE Id = :accountId];

    LINE_Message__c msg = new LINE_Message__c(
      Account__c = accountId,
      Direction__c = 'Outbound',
      Message_Type__c = 'Text',
      Message_Body__c = text,
      LINE_User_ID__c = acc.LINE_User_ID__c,
      Sent_At__c = System.now()
    );

    // Push before insert: Apex forbids a callout after DML in the same transaction.
    // Customers without a LINE id get a local-only message with no delivery status.
    if (String.isNotBlank(acc.LINE_User_ID__c)) {
      LineMessagingService.PushResult result = LineMessagingService.pushText(
        acc.LINE_User_ID__c,
        text
      );
      msg.Delivery_Status__c = result.success ? 'Sent' : 'Failed';
      msg.Delivery_Error__c = result.error;
    }
    insert msg;
    return msg;
  }

  private static AuraHandledException auraError(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
