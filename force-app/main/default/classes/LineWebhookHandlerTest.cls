@IsTest
private class LineWebhookHandlerTest {
  static final String SECRET = 'test-channel-secret';

  private class ProfileMock implements HttpCalloutMock {
    Integer status;
    Integer calls = 0;
    ProfileMock(Integer status) {
      this.status = status;
    }
    public HttpResponse respond(HttpRequest req) {
      calls++;
      HttpResponse res = new HttpResponse();
      res.setStatusCode(status);
      res.setBody(
        status == 200
          ? '{"userId":"U_new","displayName":"สมหญิง ใจดี","pictureUrl":"https://example.com/p.png"}'
          : '{"message":"Not found"}'
      );
      return res;
    }
  }

  @TestSetup
  static void setup() {
    insert new LINE_Settings__c(
      SetupOwnerId = UserInfo.getOrganizationId(),
      Channel_Secret__c = SECRET
    );
    Id personType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('PersonAccount')
      .getRecordTypeId();
    insert new Account(
      RecordTypeId = personType,
      FirstName = 'Test',
      LastName = 'Customer',
      LINE_User_ID__c = 'U_known'
    );
  }

  static String textEvent(String userId, String messageId, String text) {
    return '{"type":"message","timestamp":1790000000000,"source":{"type":"user","userId":"' +
      userId +
      '"},' +
      '"message":{"type":"text","id":"' +
      messageId +
      '","text":"' +
      text +
      '"}}';
  }

  static String followEvent(String userId, String eventId) {
    return '{"type":"follow","webhookEventId":"' +
      eventId +
      '","timestamp":1790000000000,"source":{"type":"user","userId":"' +
      userId +
      '"}}';
  }

  static Integer post(String body, String signature) {
    RestRequest req = new RestRequest();
    req.requestURI = '/services/apexrest/line/webhook';
    req.httpMethod = 'POST';
    req.requestBody = Blob.valueOf(body);
    if (signature != null) {
      req.headers.put('x-line-signature', signature);
    }
    RestContext.request = req;
    RestContext.response = new RestResponse();
    LineWebhookHandler.receive();
    return RestContext.response.statusCode;
  }

  static Integer postSigned(String body) {
    return post(body, sign(body));
  }

  static String sign(String body) {
    return EncodingUtil.base64Encode(
      Crypto.generateMac('hmacSHA256', Blob.valueOf(body), Blob.valueOf(SECRET))
    );
  }

  static String events(String eventJson) {
    return '{"destination":"Ubot","events":[' + eventJson + ']}';
  }

  @IsTest
  static void savesTextMessageForKnownCustomer() {
    ProfileMock mock = new ProfileMock(200);
    Test.setMock(HttpCalloutMock.class, mock);

    Assert.areEqual(
      200,
      postSigned(events(textEvent('U_known', 'm1', 'สวัสดีครับ')))
    );

    LINE_Message__c m = [
      SELECT
        Account__r.LastName,
        Direction__c,
        Message_Body__c,
        LINE_Message_ID__c,
        Sent_At__c
      FROM LINE_Message__c
    ];
    Assert.areEqual('Customer', m.Account__r.LastName);
    Assert.areEqual('Inbound', m.Direction__c);
    Assert.areEqual('สวัสดีครับ', m.Message_Body__c);
    Assert.areEqual('m1', m.LINE_Message_ID__c);
    Assert.areEqual(Datetime.newInstance(1790000000000L), m.Sent_At__c);
    Assert.areEqual(0, mock.calls, 'Known customers need no profile lookup');
    Assert.areEqual(1, [SELECT COUNT() FROM Account]);
  }

  @IsTest
  static void rejectsBadSignature() {
    String body = events(textEvent('U_known', 'm1', 'hi'));

    Assert.areEqual(401, post(body, sign(body).toLowerCase()));
    Assert.areEqual(401, post(body, null));
    Assert.areEqual(0, [SELECT COUNT() FROM LINE_Message__c]);
  }

  @IsTest
  static void newFriendBecomesLeadNamedAfterLineProfile() {
    Test.setMock(HttpCalloutMock.class, new ProfileMock(200));

    // startTest: the profile lookup is a callout, which can't follow the @TestSetup DML otherwise.
    Test.startTest();
    postSigned(events(followEvent('U_new', '01J0FOLLOW')));
    Test.stopTest();

    Lead l = [
      SELECT LastName, Company, LeadSource, IsConverted
      FROM Lead
      WHERE LINE_User_ID__c = 'U_new'
    ];
    Assert.areEqual('สมหญิง ใจดี', l.LastName);
    Assert.isNull(l.Company, 'Blank so it converts to a Person Account');
    Assert.areEqual('LINE', l.LeadSource);
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Account WHERE LINE_User_ID__c = 'U_new']
    );
    LINE_Message__c m = [
      SELECT Lead__c, Account__c, Message_Body__c, LINE_Message_ID__c
      FROM LINE_Message__c
    ];
    Assert.areEqual(l.Id, m.Lead__c);
    Assert.isNull(m.Account__c);
    Assert.areEqual('[Added the OA as a friend]', m.Message_Body__c);
    Assert.areEqual('follow:01J0FOLLOW', m.LINE_Message_ID__c);
  }

  @IsTest
  static void existingLeadGetsTheMessageAndNoNewLead() {
    Lead l = new Lead(LastName = 'Known Lead', LINE_User_ID__c = 'U_lead');
    insert l;

    postSigned(events(textEvent('U_lead', 'm9', 'any plans?')));

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Lead WHERE LINE_User_ID__c = 'U_lead']
    );
    Assert.areEqual(
      l.Id,
      [SELECT Lead__c FROM LINE_Message__c WHERE LINE_Message_ID__c = 'm9']
      .Lead__c
    );
  }

  @IsTest
  static void accountWinsOverLeadWithTheSameLineId() {
    insert new Lead(LastName = 'Old Lead', LINE_User_ID__c = 'U_known');

    postSigned(events(textEvent('U_known', 'm10', 'hi')));

    LINE_Message__c m = [
      SELECT Account__c, Lead__c
      FROM LINE_Message__c
      WHERE LINE_Message_ID__c = 'm10'
    ];
    Assert.isNotNull(m.Account__c);
    Assert.isNull(m.Lead__c);
  }

  @IsTest
  static void unknownSenderGetsLeadAndEarlierMessagesAreAttached() {
    Test.setMock(HttpCalloutMock.class, new ProfileMock(200));
    insert new LINE_Message__c(
      LINE_User_ID__c = 'U_new',
      Direction__c = 'Inbound',
      Message_Body__c = 'sent before the lead existed'
    );

    Test.startTest();
    postSigned(events(textEvent('U_new', 'm2', 'hello')));
    Test.stopTest();

    Id leadId = [SELECT Id FROM Lead WHERE LINE_User_ID__c = 'U_new'].Id;
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM LINE_Message__c WHERE Lead__c = :leadId]
    );
  }

  @IsTest
  static void usesPlaceholderNameWhenProfileLookupFails() {
    Test.setMock(HttpCalloutMock.class, new ProfileMock(404));

    Test.startTest();
    postSigned(events(followEvent('U_nobody1234', 'ev1')));
    Test.stopTest();

    Assert.areEqual(
      'LINE friend 1234',
      [SELECT LastName FROM Lead WHERE LINE_User_ID__c = 'U_nobody1234']
      .LastName
    );
  }

  @IsTest
  static void placeholderNameIsReplacedOnTheNextMessage() {
    insert new Lead(LastName = 'LINE friend _new', LINE_User_ID__c = 'U_new');
    Test.setMock(HttpCalloutMock.class, new ProfileMock(200));

    Test.startTest();
    postSigned(events(textEvent('U_new', 'm5', 'hello again')));
    Test.stopTest();

    Assert.areEqual(
      'สมหญิง ใจดี',
      [SELECT LastName FROM Lead WHERE LINE_User_ID__c = 'U_new'].LastName
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Lead WHERE LINE_User_ID__c = 'U_new']
    );
  }

  @IsTest
  static void redeliveredEventsCreateNothingTwice() {
    Test.setMock(HttpCalloutMock.class, new ProfileMock(200));
    String body = events(
      followEvent('U_new', 'ev-follow') + ',' + textEvent('U_new', 'm3', 'once')
    );

    Test.startTest();
    postSigned(body);
    postSigned(body);
    Test.stopTest();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Lead WHERE LINE_User_ID__c = 'U_new']
    );
    Assert.areEqual(2, [SELECT COUNT() FROM LINE_Message__c]);
  }

  @IsTest
  static void labelsNonTextMessagesAndIgnoresOtherEvents() {
    String sticker = '{"type":"message","source":{"userId":"U_known"},"message":{"type":"sticker","id":"m4"}}';
    String unfollow = '{"type":"unfollow","source":{"userId":"U_known"}}';

    postSigned(events(sticker + ',' + unfollow));

    Assert.areEqual(
      '[Sticker]',
      [SELECT Message_Body__c FROM LINE_Message__c].Message_Body__c
    );
  }

  @IsTest
  static void acceptsLineVerifyRequestWithNoEvents() {
    Assert.areEqual(200, postSigned('{"destination":"Ubot","events":[]}'));
  }

  @IsTest
  static void failsClearlyWhenSecretMissing() {
    delete [SELECT Id FROM LINE_Settings__c];

    Assert.areEqual(500, postSigned('{"events":[]}'));
  }
}
