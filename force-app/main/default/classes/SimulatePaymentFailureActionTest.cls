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
    insert new Contracts__c(
      Account__c = acc.Id,
      Status__c = 'Active',
      Contract_Start_Date__c = Date.today(),
      Contract_Term_months__c = 12,
      Subscription_Plan__c = 'Premium (1,500 THB)',
      Stripe_Sub_ID__c = 'sub_demo_12345'
    );
  }

  // End to end: button -> failed payment -> Payment Failure Recovery flow -> retry message on LINE.
  @IsTest
  static void failedPaymentRunsTheWholeRecovery() {
    Test.setMock(HttpCalloutMock.class, new LineMock());
    Contracts__c c = [SELECT Id, Account__c FROM Contracts__c LIMIT 1];

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
    Assert.areEqual(c.Account__c, p.Account__c);

    Assert.areEqual(
      'Payment Failed',
      [SELECT Status__c FROM Contracts__c WHERE Id = :c.Id].Status__c
    );
    Assert.areEqual(
      'Payment Suspended',
      [SELECT Customer_Status__c FROM Account WHERE Id = :c.Account__c]
      .Customer_Status__c
    );

    LINE_Message__c msg = [
      SELECT Message_Type__c, Message_Body__c, Delivery_Status__c, Account__c
      FROM LINE_Message__c
    ];
    Assert.areEqual('Payment Retry', msg.Message_Type__c);
    Assert.isTrue(
      msg.Message_Body__c.startsWith(
        'Hi Test,\nPayment failed for your monthly subscription.'
      )
    );
    Assert.areEqual('Sent', msg.Delivery_Status__c);
    Assert.areEqual(c.Account__c, msg.Account__c);
    Assert.isTrue(
      msg.Message_Body__c.endsWith(
        'https://checkout.stripe.com/demo/sub_demo_12345/update-payment'
      )
    );
  }

  @IsTest
  static void successfulPaymentDoesNotTriggerRecovery() {
    Contracts__c c = [SELECT Id FROM Contracts__c LIMIT 1];
    // The payment success flow sends a "payment received" message.
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());

    Test.startTest();
    insert new Payment_History__c(
      Subscription_Contract__c = c.Id,
      Amount__c = 1500,
      Status__c = 'Success'
    );
    Test.stopTest();

    Assert.areEqual(
      'Active',
      [SELECT Status__c FROM Contracts__c WHERE Id = :c.Id].Status__c
    );
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM LINE_Message__c
        WHERE Message_Type__c = 'Payment Retry'
      ]
    );
  }

  // A lead's first payment fails after the checkout link: a Pending Payment contract is created
  // for the lead, the recovery flow marks it Payment Failed, and the retry link goes to the
  // lead's LINE chat.
  @IsTest
  static void leadFirstPaymentFailsAndGetsTheRetryLink() {
    Lead l = new Lead(
      FirstName = 'Somying',
      LastName = 'Jaidee',
      LINE_User_ID__c = 'U_lead_fail',
      LeadSource = 'LINE',
      Subscription_Plan__c = 'Standard (900 THB)',
      Stripe_Sub_ID__c = 'sub_demo_lead99'
    );
    insert l;
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());

    Test.startTest();
    SimulatePaymentFailureAction.simulate(l.Id);
    Test.stopTest();

    Contracts__c c = [
      SELECT Status__c, Account__c, Subscription_Plan__c, Stripe_Sub_ID__c
      FROM Contracts__c
      WHERE Lead__c = :l.Id
    ];
    Assert.areEqual('Payment Failed', c.Status__c);
    Assert.isNull(c.Account__c);
    Assert.areEqual('Standard (900 THB)', c.Subscription_Plan__c);
    Assert.areEqual('sub_demo_lead99', c.Stripe_Sub_ID__c);

    Payment_History__c p = [
      SELECT Amount__c, Status__c, Lead__c
      FROM Payment_History__c
      WHERE Subscription_Contract__c = :c.Id
    ];
    Assert.areEqual(900, p.Amount__c);
    Assert.areEqual('Failed', p.Status__c);
    Assert.areEqual(l.Id, p.Lead__c);

    LINE_Message__c msg = [
      SELECT
        Lead__c,
        Account__c,
        Message_Type__c,
        Message_Body__c,
        Delivery_Status__c
      FROM LINE_Message__c
      WHERE Message_Type__c = 'Payment Retry'
    ];
    Assert.areEqual(l.Id, msg.Lead__c);
    Assert.isNull(msg.Account__c);
    Assert.areEqual('Sent', msg.Delivery_Status__c);
    Assert.isTrue(msg.Message_Body__c.startsWith('Hi Somying,'));
    Assert.isTrue(
      msg.Message_Body__c.endsWith(
        'https://checkout.stripe.com/demo/sub_demo_lead99/update-payment'
      )
    );
  }

  @IsTest
  static void leadFailingTwiceKeepsOneContract() {
    Lead l = new Lead(
      LastName = 'Twice',
      Subscription_Plan__c = 'Premium (1,500 THB)',
      Stripe_Sub_ID__c = 'sub_demo_twice'
    );
    insert l;
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());

    SimulatePaymentFailureAction.simulate(l.Id);
    SimulatePaymentFailureAction.simulate(l.Id);

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM Contracts__c WHERE Lead__c = :l.Id]
    );
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM Payment_History__c WHERE Lead__c = :l.Id]
    );
  }

  @IsTest
  static void leadNeedsTheCheckoutLinkFirst() {
    Lead l = new Lead(
      LastName = 'No Checkout',
      Subscription_Plan__c = 'Standard (900 THB)'
    );
    insert l;

    try {
      SimulatePaymentFailureAction.simulate(l.Id);
      Assert.fail('Expected an error');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('checkout link first'));
    }
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Contracts__c WHERE Lead__c = :l.Id]
    );
  }
}
