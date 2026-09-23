@IsTest
private class LineWebhookHandlerTest {
  static final String SECRET = 'test-channel-secret';

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

  static String sign(String body) {
    return EncodingUtil.base64Encode(
      Crypto.generateMac('hmacSHA256', Blob.valueOf(body), Blob.valueOf(SECRET))
    );
  }

  @IsTest
  static void savesTextMessageForKnownCustomer() {
    String body =
      '{"destination":"Ubot","events":[' +
      textEvent('U_known', 'm1', 'สวัสดีครับ') +
      ']}';

    Assert.areEqual(200, post(body, sign(body)));

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
  }

  @IsTest
  static void rejectsBadSignature() {
    String body = '{"events":[' + textEvent('U_known', 'm1', 'hi') + ']}';

    Assert.areEqual(401, post(body, sign(body).toLowerCase()));
    Assert.areEqual(401, post(body, null));
    Assert.areEqual(0, [SELECT COUNT() FROM LINE_Message__c]);
  }

  @IsTest
  static void savesUnknownSenderWithoutAccount() {
    String body = '{"events":[' + textEvent('U_stranger', 'm2', 'hello') + ']}';

    post(body, sign(body));

    LINE_Message__c m = [
      SELECT Account__c, LINE_User_ID__c
      FROM LINE_Message__c
    ];
    Assert.isNull(m.Account__c);
    Assert.areEqual('U_stranger', m.LINE_User_ID__c);
  }

  @IsTest
  static void skipsRedeliveredMessage() {
    String body = '{"events":[' + textEvent('U_known', 'm3', 'once') + ']}';

    post(body, sign(body));
    post(body, sign(body));

    Assert.areEqual(1, [SELECT COUNT() FROM LINE_Message__c]);
  }

  @IsTest
  static void labelsNonTextMessagesAndIgnoresOtherEvents() {
    String sticker = '{"type":"message","source":{"userId":"U_known"},"message":{"type":"sticker","id":"m4"}}';
    String follow = '{"type":"follow","source":{"userId":"U_known"}}';
    String body = '{"events":[' + sticker + ',' + follow + ']}';

    post(body, sign(body));

    Assert.areEqual(
      '[Sticker]',
      [SELECT Message_Body__c FROM LINE_Message__c].Message_Body__c
    );
  }

  @IsTest
  static void acceptsLineVerifyRequestWithNoEvents() {
    String body = '{"destination":"Ubot","events":[]}';

    Assert.areEqual(200, post(body, sign(body)));
  }

  @IsTest
  static void failsClearlyWhenSecretMissing() {
    delete [SELECT Id FROM LINE_Settings__c];
    String body = '{"events":[]}';

    Assert.areEqual(500, post(body, sign(body)));
  }
}
