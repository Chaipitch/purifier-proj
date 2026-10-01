public with sharing class LineMessagingService {
  // Name given to leads created from LINE when the display name lookup fails.
  public static final String PLACEHOLDER_PREFIX = 'LINE friend ';

  // Greeting line ("Hi" + first name, else last name) to open a message with.
  // Empty for placeholder or missing names, so the message still reads naturally.
  public static String addressAs(String firstName, String lastName) {
    String name = String.isNotBlank(firstName) ? firstName : lastName;
    if (String.isBlank(name) || name.startsWith(PLACEHOLDER_PREFIX)) {
      return '';
    }
    return 'Hi ' + name + ',\n';
  }

  public class PushResult {
    public Boolean success = false;
    public String error;
  }

  // Who a chat on a Lead, Account or Case page talks to. A Case talks to its Account's LINE
  // user; a converted Lead talks to the Account it became.
  public class Recipient {
    public Id accountId;
    public Id leadId;
    public Id caseId;
    public String lineUserId;
    public String name;
    public String firstName;
    public String lastName;
  }

  public static Recipient recipientFor(Id recordId) {
    Recipient r = new Recipient();
    SObjectType type = recordId.getSObjectType();
    if (type == Lead.SObjectType) {
      Lead l = [
        SELECT
          Name,
          FirstName,
          LastName,
          LINE_User_ID__c,
          IsConverted,
          ConvertedAccountId
        FROM Lead
        WHERE Id = :recordId
      ];
      if (l.IsConverted && l.ConvertedAccountId != null) {
        return recipientFor(l.ConvertedAccountId);
      }
      r.leadId = l.Id;
      r.lineUserId = l.LINE_User_ID__c;
      r.name = l.Name;
      r.firstName = l.FirstName;
      r.lastName = l.LastName;
    } else if (type == Case.SObjectType) {
      Case c = [SELECT AccountId FROM Case WHERE Id = :recordId];
      if (c.AccountId != null) {
        r = recipientFor(c.AccountId);
      }
      r.caseId = recordId;
    } else {
      Account a = [
        SELECT Name, FirstName, LastName, LINE_User_ID__c
        FROM Account
        WHERE Id = :recordId
      ];
      r.accountId = a.Id;
      r.lineUserId = a.LINE_User_ID__c;
      r.name = a.Name;
      r.firstName = a.FirstName;
      r.lastName = a.LastName;
    }
    return r;
  }

  // recordId: the Lead, Account or Case the message is sent from.
  public static LINE_Message__c sendAndSave(
    Id recordId,
    String text,
    String messageType
  ) {
    LINE_Message__c msg = outbound(recipientFor(recordId), text, messageType);
    pushAndInsert(new List<LINE_Message__c>{ msg });
    return msg;
  }

  public static LINE_Message__c outbound(
    Recipient to,
    String text,
    String messageType
  ) {
    LINE_Message__c msg = outbound(
      to.accountId,
      to.lineUserId,
      text,
      messageType
    );
    msg.Lead__c = to.leadId;
    msg.Case__c = to.caseId;
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

  // The customer's LINE display name, or null if LINE can't be reached or doesn't return one.
  public static String fetchDisplayName(String lineUserId) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
      'callout:LINE_Messaging_API/v2/bot/profile/' +
      EncodingUtil.urlEncode(lineUserId, 'UTF-8')
    );
    req.setMethod('GET');
    req.setTimeout(5000);
    try {
      HttpResponse res = new Http().send(req);
      if (res.getStatusCode() != 200) {
        return null;
      }
      Object name = ((Map<String, Object>) JSON.deserializeUntyped(
          res.getBody()
        ))
        .get('displayName');
      return name instanceof String && String.isNotBlank((String) name)
        ? ((String) name).left(80)
        : null;
    } catch (CalloutException e) {
      return null;
    } catch (JSONException e) {
      return null;
    }
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
