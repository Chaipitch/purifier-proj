@IsTest
private class SendCheckoutLinkActionTest {
  private class LineMock implements HttpCalloutMock {
    Integer status;
    String lastBody;
    LineMock(Integer status) {
      this.status = status;
    }
    public HttpResponse respond(HttpRequest req) {
      lastBody = req.getBody();
      HttpResponse res = new HttpResponse();
      res.setStatusCode(status);
      res.setBody(status == 200 ? '{}' : '{"message":"Invalid reply token"}');
      return res;
    }
  }

  @TestSetup
  static void setup() {
    Id personType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('PersonAccount')
      .getRecordTypeId();
    Account acc = new Account(
      RecordTypeId = personType,
      FirstName = 'Test',
      LastName = 'Customer',
      LINE_User_ID__c = 'U_test_123'
    );
    insert acc;
    insert new Contracts__c(
      Account__c = acc.Id,
      Status__c = 'Pending Payment',
      Contract_Start_Date__c = Date.today(),
      Contract_Term_months__c = 12,
      Subscription_Plan__c = 'Premium (1,500 THB)',
      Stripe_Sub_ID__c = 'sub_demo_12345'
    );
  }

  static SendCheckoutLinkAction.Result run() {
    return SendCheckoutLinkAction.send(
      [SELECT Id FROM Contracts__c LIMIT 1].Id
    );
  }

  @IsTest
  static void sendsMockCheckoutLinkAndSavesItInTheChat() {
    LineMock mock = new LineMock(200);
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SendCheckoutLinkAction.Result result = run();
    Test.stopTest();

    Assert.areEqual('Sent', result.status);
    LINE_Message__c msg = [
      SELECT Message_Type__c, Message_Body__c, Direction__c, Delivery_Status__c
      FROM LINE_Message__c
    ];
    Assert.areEqual('Checkout Link', msg.Message_Type__c);
    Assert.areEqual('Outbound', msg.Direction__c);
    Assert.areEqual('Sent', msg.Delivery_Status__c);
    Assert.isTrue(
      msg.Message_Body__c.endsWith(
        'https://checkout.stripe.com/demo/sub_demo_12345'
      )
    );
    Assert.isTrue(msg.Message_Body__c.contains('Premium (1,500 THB)'));
    Assert.isTrue(
      msg.Message_Body__c.startsWith('Hi Test,\nThank you for choosing NORITZ.')
    );
    Assert.isTrue(
      mock.lastBody.contains('checkout.stripe.com/demo/sub_demo_12345')
    );
  }

  @IsTest
  static void reportsLineRejection() {
    Test.setMock(HttpCalloutMock.class, new LineMock(400));

    Test.startTest();
    SendCheckoutLinkAction.Result result = run();
    Test.stopTest();

    Assert.areEqual('Failed', result.status);
    Assert.isTrue(result.message.contains('LINE 400'));
    Assert.areEqual(1, [SELECT COUNT() FROM LINE_Message__c]);
  }

  @IsTest
  static void savesLocallyWhenCustomerHasNoLineAccount() {
    Account acc = [SELECT Id FROM Account LIMIT 1];
    acc.LINE_User_ID__c = null;
    update acc;

    SendCheckoutLinkAction.Result result = run();

    Assert.areEqual('Not linked', result.status);
    Assert.areEqual(1, [SELECT COUNT() FROM LINE_Message__c]);
  }

  @IsTest
  static void refusesContractWithoutSubscriptionId() {
    Contracts__c c = [SELECT Id FROM Contracts__c LIMIT 1];
    c.Stripe_Sub_ID__c = null;
    update c;

    SendCheckoutLinkAction.Result result = run();

    Assert.areEqual('Error', result.status);
    Assert.areEqual(0, [SELECT COUNT() FROM LINE_Message__c]);
  }

  @IsTest
  static void leadGetsLinkSubscriptionIdAndStatus() {
    Lead l = new Lead(
      LastName = 'Lead Friend',
      LINE_User_ID__c = 'U_lead_9',
      Subscription_Plan__c = 'Premium (1,500 THB)'
    );
    insert l;
    LineMock mock = new LineMock(200);
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SendCheckoutLinkAction.Result result = SendCheckoutLinkAction.send(l.Id);
    Test.stopTest();

    Assert.areEqual('Sent', result.status);
    Lead saved = [SELECT Stripe_Sub_ID__c, Status FROM Lead WHERE Id = :l.Id];
    Assert.isTrue(saved.Stripe_Sub_ID__c.startsWith('sub_demo_'));
    Assert.areEqual('Working - Contacted', saved.Status);
    LINE_Message__c msg = [
      SELECT Lead__c, Message_Type__c, Message_Body__c
      FROM LINE_Message__c
    ];
    Assert.areEqual(l.Id, msg.Lead__c);
    Assert.areEqual('Checkout Link', msg.Message_Type__c);
    Assert.isTrue(msg.Message_Body__c.endsWith(saved.Stripe_Sub_ID__c));
  }

  @IsTest
  static void leadWithoutPlanGetsNoLink() {
    Lead l = new Lead(LastName = 'No Plan', LINE_User_ID__c = 'U_lead_10');
    insert l;

    SendCheckoutLinkAction.Result result = SendCheckoutLinkAction.send(l.Id);

    Assert.areEqual('Error', result.status);
    Assert.areEqual(0, [SELECT COUNT() FROM LINE_Message__c]);
  }
}
