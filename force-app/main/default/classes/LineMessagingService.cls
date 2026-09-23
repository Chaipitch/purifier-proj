public with sharing class LineMessagingService {
  public class PushResult {
    public Boolean success = false;
    public String error;
  }

  public static LINE_Message__c sendAndSave(
    Id accountId,
    String text,
    String messageType
  ) {
    Account acc = [SELECT LINE_User_ID__c FROM Account WHERE Id = :accountId];
    LINE_Message__c msg = outbound(
      accountId,
      acc.LINE_User_ID__c,
      text,
      messageType
    );
    pushAndInsert(new List<LINE_Message__c>{ msg });
    return msg;
  }

  public static LINE_Message__c outbound(
    Id accountId,
    String lineUserId,
    String text,
    String messageType
  ) {
    return new LINE_Message__c(
      Account__c = accountId,
      Direction__c = 'Outbound',
      Message_Type__c = messageType,
      Message_Body__c = text,
      LINE_User_ID__c = lineUserId,
      Sent_At__c = System.now()
    );
  }

  // Every push happens before the single insert: Apex forbids a callout after DML in the
  // same transaction. Messages to customers without a LINE id are saved with no delivery status.
  public static void pushAndInsert(List<LINE_Message__c> messages) {
    for (LINE_Message__c msg : messages) {
      if (String.isNotBlank(msg.LINE_User_ID__c)) {
        PushResult result = pushText(msg.LINE_User_ID__c, msg.Message_Body__c);
        msg.Delivery_Status__c = result.success ? 'Sent' : 'Failed';
        msg.Delivery_Error__c = result.error;
      }
    }
    insert messages;
  }

  public static PushResult pushText(String lineUserId, String text) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:LINE_Messaging_API/v2/bot/message/push');
    req.setMethod('POST');
    req.setTimeout(10000);
    req.setHeader('Content-Type', 'application/json');
    // LINE ignores a repeated request with the same retry key, so a retried send can't arrive twice.
    req.setHeader('X-Line-Retry-Key', UUID.randomUUID().toString());
    req.setBody(
      JSON.serialize(
        new Map<String, Object>{
          'to' => lineUserId,
          'messages' => new List<Object>{
            new Map<String, Object>{ 'type' => 'text', 'text' => text }
          }
        }
      )
    );

    PushResult result = new PushResult();
    try {
      HttpResponse res = new Http().send(req);
      result.success = res.getStatusCode() == 200;
      if (!result.success) {
        result.error = ('LINE ' +
          res.getStatusCode() +
          ': ' +
          res.getBody())
          .left(255);
      }
    } catch (CalloutException e) {
      result.error = e.getMessage().left(255);
    }
    return result;
  }
}
