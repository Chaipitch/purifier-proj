// Called by the LINE platform through the public Site, so it runs as the Site guest user.
// The guest user can't see Accounts or earlier messages, so lookups and the insert run in system
// mode (at this API version they otherwise respect the running user's access even without sharing).
// That is safe only because every request passes the X-Line-Signature check first.
@RestResource(urlMapping='/line/webhook/*')
global without sharing class LineWebhookHandler {
  @HttpPost
  global static void receive() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    String secret = LINE_Settings__c.getOrgDefaults().Channel_Secret__c;
    if (String.isBlank(secret)) {
      respond(res, 500, 'Channel secret is not configured');
      return;
    }
    if (
      !isValidSignature(
        req.requestBody,
        header(req, 'x-line-signature'),
        secret
      )
    ) {
      respond(res, 401, 'Invalid signature');
      return;
    }

    Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
      req.requestBody.toString()
    );
    saveMessages((List<Object>) payload.get('events'));
    respond(res, 200, 'ok');
  }

  @TestVisible
  private static Boolean isValidSignature(
    Blob body,
    String signature,
    String secret
  ) {
    if (body == null || String.isBlank(signature)) {
      return false;
    }
    String expected = EncodingUtil.base64Encode(
      Crypto.generateMac('hmacSHA256', body, Blob.valueOf(secret))
    );
    // equals(), not ==: Apex string == ignores case, which would weaken the check.
    return expected.equals(signature);
  }

  private static void saveMessages(List<Object> events) {
    if (events == null || events.isEmpty()) {
      return;
    }

    List<Map<String, Object>> messageEvents = new List<Map<String, Object>>();
    Set<String> userIds = new Set<String>();
    Set<String> messageIds = new Set<String>();
    for (Object item : events) {
      Map<String, Object> ev = (Map<String, Object>) item;
      Map<String, Object> source = (Map<String, Object>) ev.get('source');
      Map<String, Object> message = (Map<String, Object>) ev.get('message');
      if (
        ev.get('type') != 'message' ||
        source == null ||
        message == null ||
        source.get('userId') == null
      ) {
        continue;
      }
      messageEvents.add(ev);
      userIds.add((String) source.get('userId'));
      messageIds.add((String) message.get('id'));
    }
    if (messageEvents.isEmpty()) {
      return;
    }

    Set<String> alreadySaved = new Set<String>();
    for (LINE_Message__c m : [
      SELECT LINE_Message_ID__c
      FROM LINE_Message__c
      WHERE LINE_Message_ID__c IN :messageIds
      WITH SYSTEM_MODE
    ]) {
      alreadySaved.add(m.LINE_Message_ID__c);
    }
    Map<String, Id> accountByLineId = new Map<String, Id>();
    for (Account a : [
      SELECT Id, LINE_User_ID__c
      FROM Account
      WHERE LINE_User_ID__c IN :userIds
      WITH SYSTEM_MODE
      ORDER BY CreatedDate
    ]) {
      if (!accountByLineId.containsKey(a.LINE_User_ID__c)) {
        accountByLineId.put(a.LINE_User_ID__c, a.Id);
      }
    }

    List<LINE_Message__c> toInsert = new List<LINE_Message__c>();
    for (Map<String, Object> ev : messageEvents) {
      Map<String, Object> message = (Map<String, Object>) ev.get('message');
      String messageId = (String) message.get('id');
      if (alreadySaved.contains(messageId)) {
        continue;
      }
      String userId = (String) ((Map<String, Object>) ev.get('source'))
        .get('userId');
      toInsert.add(
        new LINE_Message__c(
          Account__c = accountByLineId.get(userId),
          LINE_User_ID__c = userId,
          LINE_Message_ID__c = messageId,
          Direction__c = 'Inbound',
          Message_Type__c = 'Text',
          Message_Body__c = bodyOf(message),
          Sent_At__c = sentAt(ev.get('timestamp'))
        )
      );
    }
    // allOrNone=false: if LINE redelivers the same message concurrently, the unique
    // LINE_Message_ID__c rejects the duplicate without failing the rest.
    Database.insert(toInsert, false, AccessLevel.SYSTEM_MODE);
  }

  private static String bodyOf(Map<String, Object> message) {
    String type = (String) message.get('type');
    if (type == 'text') {
      return ((String) message.get('text')).left(4000);
    }
    return '[' + type.capitalize() + ']';
  }

  private static Datetime sentAt(Object timestampMillis) {
    return timestampMillis == null
      ? System.now()
      : Datetime.newInstance(Long.valueOf(String.valueOf(timestampMillis)));
  }

  private static String header(RestRequest req, String name) {
    for (String key : req.headers.keySet()) {
      if (key.equalsIgnoreCase(name)) {
        return req.headers.get(key);
      }
    }
    return null;
  }

  private static void respond(
    RestResponse res,
    Integer status,
    String message
  ) {
    res.statusCode = status;
    res.addHeader('Content-Type', 'application/json');
    res.responseBody = Blob.valueOf(
      JSON.serialize(new Map<String, String>{ 'status' => message })
    );
  }
}
