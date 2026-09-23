@IsTest
private class SimulatePaymentFailureActionTest {
  private class LineMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody('{}');
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
      LINE_User_ID__c = 'U_test_123',
      Customer_Status__c = 'Active'
    );
    insert acc;
    Contract c = new Contract(
      AccountId = acc.Id,
      Status = 'Pending Payment',
      StartDate = Date.today(),
      ContractTerm = 12,
      Subscription_Plan__c = 'Premium (1,500 THB)',
      Stripe_Sub_ID__c = 'sub_demo_12345'
    );
    insert c;
    c.Status = 'Active';
    update c;
  }

  // End to end: button -> failed payment -> Payment Failure Recovery flow -> retry message on LINE.
  @IsTest
  static void failedPaymentRunsTheWholeRecovery() {
    Test.setMock(HttpCalloutMock.class, new LineMock());
    Contract c = [SELECT Id, AccountId FROM Contract LIMIT 1];

    Test.startTest();
    SimulatePaymentFailureAction.simulate(c.Id);
    Test.stopTest();

    Payment_History__c p = [
      SELECT Amount__c, Status__c, Failure_Reason__c, Account__c
      FROM Payment_History__c
    ];
    Assert.areEqual(1500, p.Amount__c);
    Assert.areEqual('Failed', p.Status__c);
    Assert.areEqual('Card Expired (ERR-02)', p.Failure_Reason__c);
    Assert.areEqual(c.AccountId, p.Account__c);

    Assert.areEqual(
      'Payment Failed',
      [SELECT Status FROM Contract WHERE Id = :c.Id].Status
    );
    Assert.areEqual(
      'Payment Suspended',
      [SELECT Customer_Status__c FROM Account WHERE Id = :c.AccountId]
      .Customer_Status__c
    );

    LINE_Message__c msg = [
      SELECT Message_Type__c, Message_Body__c, Delivery_Status__c, Account__c
      FROM LINE_Message__c
    ];
    Assert.areEqual('Payment Retry', msg.Message_Type__c);
    Assert.areEqual('Sent', msg.Delivery_Status__c);
    Assert.areEqual(c.AccountId, msg.Account__c);
    Assert.isTrue(
      msg.Message_Body__c.endsWith(
        'https://checkout.stripe.com/demo/sub_demo_12345/update-payment'
      )
    );
  }

  @IsTest
  static void successfulPaymentDoesNotTriggerRecovery() {
    Contract c = [SELECT Id, AccountId FROM Contract LIMIT 1];

    Test.startTest();
    insert new Payment_History__c(
      Contract__c = c.Id,
      Amount__c = 1500,
      Status__c = 'Success'
    );
    Test.stopTest();

    Assert.areEqual(
      'Active',
      [SELECT Status FROM Contract WHERE Id = :c.Id].Status
    );
    Assert.areEqual(0, [SELECT COUNT() FROM LINE_Message__c]);
  }
}
