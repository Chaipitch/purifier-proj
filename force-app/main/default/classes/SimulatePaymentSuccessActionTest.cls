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
    Contract c = new Contract(
      AccountId = acc.Id,
      Status = 'Pending Payment',
      StartDate = Date.today(),
      ContractTerm = 12,
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
      WHERE Contract__c = :c.Id
    ];
    Assert.areEqual(900, p.Amount__c);
    Assert.areEqual('Success', p.Status__c);
    Assert.areEqual(acc.Id, p.Account__c);
    Assert.areEqual(
      'Active',
      [SELECT Status FROM Contract WHERE Id = :c.Id].Status
    );
  }
}
