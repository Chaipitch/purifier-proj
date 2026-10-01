// Called by the LINE platform through the public Site, so it runs as the Site guest user.
// The guest user can't see Accounts or earlier messages, so queries and DML run in system
// mode (at this API version they otherwise respect the running user's access even without sharing).
// That is safe only because every request passes the X-Line-Signature check first.
@RestResource(urlMapping='/line/webhook/*')
global without sharing class LineWebhookHandler {
  @TestVisible
  private static final String FOLLOW_TEXT = '[Added the OA as a friend]';
  @TestVisible
  private static final String LEAD_SOURCE = 'LINE';

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
    processEvents((List<Object>) payload.get('events'));
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

  private static void processEvents(List<Object> events) {
    if (events == null || events.isEmpty()) {
      return;
    }

    List<Map<String, Object>> relevant = new List<Map<String, Object>>();
    Set<String> userIds = new Set<String>();
    Set<String> eventKeys = new Set<String>();
    for (Object item : events) {
      Map<String, Object> ev = (Map<String, Object>) item;
      String type = (String) ev.get('type');
      String userId = userIdOf(ev);
      Boolean isMessage = type == 'message' && ev.get('message') != null;
      if (userId == null || !(isMessage || type == 'follow')) {
        continue;
      }
      relevant.add(ev);
      userIds.add(userId);
      eventKeys.add(eventKey(ev));
    }
    if (relevant.isEmpty()) {
      return;
    }

    Set<String> alreadySaved = new Set<String>();
    for (LINE_Message__c m : [
      SELECT LINE_Message_ID__c
      FROM LINE_Message__c
      WHERE LINE_Message_ID__c IN :eventKeys
      WITH SYSTEM_MODE
    ]) {
      alreadySaved.add(m.LINE_Message_ID__c);
    }
    // A LINE user is an existing customer (Account) or, before their first payment, a Lead.
    Map<String, Account> accountByLineId = new Map<String, Account>();
    for (Account a : [
      SELECT Id, LastName, LINE_User_ID__c
      FROM Account
      WHERE LINE_User_ID__c IN :userIds
      WITH SYSTEM_MODE
      ORDER BY CreatedDate
    ]) {
      if (!accountByLineId.containsKey(a.LINE_User_ID__c)) {
        accountByLineId.put(a.LINE_User_ID__c, a);
      }
    }
    Map<String, Lead> leadByLineId = new Map<String, Lead>();
    for (Lead l : [
      SELECT Id, LastName, LINE_User_ID__c
      FROM Lead
      WHERE LINE_User_ID__c IN :userIds AND IsConverted = FALSE
      WITH SYSTEM_MODE
      ORDER BY CreatedDate
    ]) {
      if (!leadByLineId.containsKey(l.LINE_User_ID__c)) {
        leadByLineId.put(l.LINE_User_ID__c, l);
      }
    }

    // Profile lookups are callouts, so all of them run before the first DML below.
    Map<String, String> displayNames = new Map<String, String>();
    for (String userId : userIds) {
      Account account = accountByLineId.get(userId);
      Lead lead = leadByLineId.get(userId);
      Boolean needsName = account != null
        ? isPlaceholder(account.LastName)
        : lead == null || isPlaceholder(lead.LastName);
      if (needsName) {
        displayNames.put(userId, LineMessagingService.fetchDisplayName(userId));
      }
    }

    renamePlaceholders(accountByLineId, leadByLineId, displayNames);
    createLeads(userIds, accountByLineId, leadByLineId, displayNames);

    List<LINE_Message__c> toInsert = new List<LINE_Message__c>();
    for (Map<String, Object> ev : relevant) {
      String key = eventKey(ev);
      if (alreadySaved.contains(key)) {
        continue;
      }
      String userId = userIdOf(ev);
      Account account = accountByLineId.get(userId);
      Lead lead = account == null ? leadByLineId.get(userId) : null;
      Map<String, Object> message = (Map<String, Object>) ev.get('message');
      toInsert.add(
        new LINE_Message__c(
          Account__c = account?.Id,
          Lead__c = lead?.Id,
          LINE_User_ID__c = userId,
          LINE_Message_ID__c = key,
          Direction__c = 'Inbound',
          Message_Type__c = 'Text',
          Message_Body__c = message == null ? FOLLOW_TEXT : bodyOf(message),
          Sent_At__c = sentAt(ev.get('timestamp'))
        )
      );
    }
    // allOrNone=false: if LINE redelivers the same event concurrently, the unique
    // LINE_Message_ID__c rejects the duplicate without failing the rest.
    Database.insert(toInsert, false, AccessLevel.SYSTEM_MODE);
  }

  private static Boolean isPlaceholder(String lastName) {
    return lastName != null &&
      lastName.startsWith(LineMessagingService.PLACEHOLDER_PREFIX);
  }

  // An earlier profile lookup failed: use this event's lookup to give the record its real name.
  private static void renamePlaceholders(
    Map<String, Account> accountByLineId,
    Map<String, Lead> leadByLineId,
    Map<String, String> displayNames
  ) {
    List<SObject> renamed = new List<SObject>();
    for (String userId : displayNames.keySet()) {
      String name = displayNames.get(userId);
      if (String.isBlank(name)) {
        continue;
      }
      Account account = accountByLineId.get(userId);
      Lead lead = leadByLineId.get(userId);
      if (account != null) {
        account.LastName = name;
        renamed.add(account);
      } else if (lead != null) {
        lead.LastName = name;
        renamed.add(lead);
      }
    }
    Database.update(renamed, false, AccessLevel.SYSTEM_MODE);
  }

  // A LINE user with no Account and no open Lead becomes a Lead named after their LINE display
  // name (or a placeholder if the lookup failed). Company stays blank so the Lead converts to a
  // Person Account on the first payment. Adds them to leadByLineId.
  private static void createLeads(
    Set<String> userIds,
    Map<String, Account> accountByLineId,
    Map<String, Lead> leadByLineId,
    Map<String, String> displayNames
  ) {
    Map<String, Lead> created = new Map<String, Lead>();
    for (String userId : userIds) {
      if (
        accountByLineId.containsKey(userId) || leadByLineId.containsKey(userId)
      ) {
        continue;
      }
      String name = displayNames.get(userId);
      created.put(
        userId,
        new Lead(
          LastName = String.isBlank(name)
            ? LineMessagingService.PLACEHOLDER_PREFIX + userId.right(4)
            : name,
          LINE_User_ID__c = userId,
          LeadSource = LEAD_SOURCE
        )
      );
    }
    if (created.isEmpty()) {
      return;
    }

    Database.insert(created.values(), false, AccessLevel.SYSTEM_MODE);
    for (String userId : created.keySet()) {
      Lead lead = created.get(userId);
      if (lead.Id != null) {
        leadByLineId.put(userId, lead);
      }
    }

    // Messages that arrived before the Lead existed were saved without a customer.
    List<LINE_Message__c> earlier = [
      SELECT Id, LINE_User_ID__c
      FROM LINE_Message__c
      WHERE
        LINE_User_ID__c IN :created.keySet()
        AND Account__c = NULL
        AND Lead__c = NULL
      WITH SYSTEM_MODE
    ];
    for (LINE_Message__c m : earlier) {
      m.Lead__c = leadByLineId.get(m.LINE_User_ID__c)?.Id;
    }
    Database.update(earlier, false, AccessLevel.SYSTEM_MODE);
  }

  private static String userIdOf(Map<String, Object> ev) {
    Map<String, Object> source = (Map<String, Object>) ev.get('source');
    return source == null ? null : (String) source.get('userId');
  }

  // Unique key per LINE event, stored in LINE_Message_ID__c to skip redeliveries.
  private static String eventKey(Map<String, Object> ev) {
    Map<String, Object> message = (Map<String, Object>) ev.get('message');
    if (message != null) {
      return (String) message.get('id');
    }
    Object eventId = ev.get('webhookEventId');
    return 'follow:' +
      (eventId != null
        ? (String) eventId
        : userIdOf(ev) + ':' + String.valueOf(ev.get('timestamp')));
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
