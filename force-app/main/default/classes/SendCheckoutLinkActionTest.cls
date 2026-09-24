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
    insert new Contract(
      AccountId = acc.Id,
      Status = 'Pending Payment',
      StartDate = Date.today(),
      ContractTerm = 12,
      Subscription_Plan__c = 'Premium (1,500 THB)',
      Stripe_Sub_ID__c = 'sub_demo_12345'
    );
  }

  static SendCheckoutLinkAction.Result run() {
    return SendCheckoutLinkAction.send([SELECT Id FROM Contract LIMIT 1].Id);
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
      msg.Message_Body__c.startsWith('คุณ Test ขอบคุณที่เลือก NORITZ')
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
    Contract c = [SELECT Id FROM Contract LIMIT 1];
    c.Stripe_Sub_ID__c = null;
    update c;

    SendCheckoutLinkAction.Result result = run();

    Assert.areEqual('Error', result.status);
    Assert.areEqual(0, [SELECT COUNT() FROM LINE_Message__c]);
  }
}
