@IsTest
private class LeadConversionServiceTest {
  @TestSetup
  static void setup() {
    Lead l = new Lead(
      FirstName = 'Somying',
      LastName = 'Jaidee',
      LINE_User_ID__c = 'U_lead_conv',
      LeadSource = 'LINE',
      Subscription_Plan__c = 'Standard (900 THB)',
      Stripe_Sub_ID__c = 'sub_demo_lead01'
    );
    insert l;
    insert new LINE_Message__c(
      Lead__c = l.Id,
      LINE_User_ID__c = 'U_lead_conv',
      Direction__c = 'Inbound',
      Message_Body__c = '[Added the OA as a friend]'
    );
    // A custom asset can be recorded against the lead before it becomes a customer.
    insert new Assets__c(Name = 'NORITZ Pure Water X1', Lead__c = l.Id);
  }

  static Lead lead() {
    return [SELECT Id FROM Lead WHERE LastName = 'Jaidee'];
  }

  @IsTest
  static void firstPaymentConvertsLeadToActiveCustomer() {
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());

    Test.startTest();
    Id accountId = SimulatePaymentSuccessAction.simulate(lead().Id);
    Test.stopTest();

    Account acc = [
      SELECT
        IsPersonAccount,
        FirstName,
        LastName,
        LINE_User_ID__c,
        Customer_Status__c,
        Converted_From_LINE_Lead__c
      FROM Account
      WHERE Id = :accountId
    ];
    Assert.isTrue(acc.IsPersonAccount);
    Assert.areEqual('Somying', acc.FirstName);
    Assert.areEqual('U_lead_conv', acc.LINE_User_ID__c);
    Assert.areEqual('Active', acc.Customer_Status__c);
    Assert.isTrue(acc.Converted_From_LINE_Lead__c);
    Assert.isTrue(
      [SELECT IsConverted FROM Lead WHERE Id = :lead().Id].IsConverted
    );

    Contracts__c c = [
      SELECT Status__c, Subscription_Plan__c, Stripe_Sub_ID__c, Lead__c
      FROM Contracts__c
      WHERE Account__c = :accountId
    ];
    Assert.areEqual(
      'Active',
      c.Status__c,
      'Activated by the Payment Success flow'
    );
    Assert.areEqual('Standard (900 THB)', c.Subscription_Plan__c);
    Assert.areEqual('sub_demo_lead01', c.Stripe_Sub_ID__c);
    Assert.areEqual(lead().Id, c.Lead__c);

    Payment_History__c p = [
      SELECT Amount__c, Status__c, Lead__c
      FROM Payment_History__c
      WHERE Subscription_Contract__c = :c.Id
    ];
    Assert.areEqual(900, p.Amount__c);
    Assert.areEqual('Success', p.Status__c);
    Assert.areEqual(lead().Id, p.Lead__c);

    Assert.areEqual(
      accountId,
      [SELECT Account__c FROM LINE_Message__c WHERE Direction__c = 'Inbound']
      .Account__c,
      'The lead chat moves to the customer'
    );
    Assert.areEqual(
      accountId,
      [SELECT Account__c FROM Assets__c].Account__c,
      'The lead assets move to the customer'
    );
  }

  @IsTest
  static void refusesLeadWithoutPlan() {
    Lead l = lead();
    l.Subscription_Plan__c = null;
    update l;

    try {
      SimulatePaymentSuccessAction.simulate(l.Id);
      Assert.fail('Expected an error');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('Subscription Plan'));
    }
    Assert.isFalse([SELECT IsConverted FROM Lead WHERE Id = :l.Id].IsConverted);
  }

  @IsTest
  static void refusesConvertedLead() {
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());
    Id leadId = lead().Id;
    LeadConversionService.convertOnFirstPayment(leadId);

    try {
      SimulatePaymentSuccessAction.simulate(leadId);
      Assert.fail('Expected an error');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().contains('already been converted'));
    }
  }
}
