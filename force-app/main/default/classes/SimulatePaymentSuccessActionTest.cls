@IsTest
private class SimulatePaymentSuccessActionTest {
  @IsTest
  static void contractGetsSuccessfulPaymentAtPlanPrice() {
    Id personType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('PersonAccount')
      .getRecordTypeId();
    Account acc = new Account(
      RecordTypeId = personType,
      LastName = 'Payer',
      LINE_User_ID__c = 'U_payer'
    );
    insert acc;
    Contracts__c c = new Contracts__c(
      Account__c = acc.Id,
      Status__c = 'Pending Payment',
      Contract_Start_Date__c = Date.today(),
      Contract_Term_months__c = 12,
      Subscription_Plan__c = 'Standard (900 THB)'
    );
    insert c;
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());

    Test.startTest();
    Id converted = SimulatePaymentSuccessAction.simulate(c.Id);
    Test.stopTest();

    Assert.isNull(converted, 'Only a lead converts');
    Payment_History__c p = [
      SELECT Amount__c, Status__c, Account__c
      FROM Payment_History__c
      WHERE Subscription_Contract__c = :c.Id
    ];
    Assert.areEqual(900, p.Amount__c);
    Assert.areEqual('Success', p.Status__c);
    Assert.areEqual(acc.Id, p.Account__c);
    Assert.areEqual(
      'Active',
      [SELECT Status__c FROM Contracts__c WHERE Id = :c.Id].Status__c
    );
  }
}
