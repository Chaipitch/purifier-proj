@IsTest
private class CustomerHistoryControllerTest {
  @TestSetup
  static void setup() {
    Id personType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('PersonAccount')
      .getRecordTypeId();
    Account acc = new Account(
      RecordTypeId = personType,
      FirstName = 'Somchai',
      LastName = 'History'
    );
    insert acc;
    insert new Asset(
      Name = 'NORITZ Pure Water X1',
      SerialNumber = 'NZ-1',
      AccountId = acc.Id
    );
    Contract c = new Contract(
      AccountId = acc.Id,
      Status = 'Pending Payment',
      StartDate = Date.today(),
      ContractTerm = 12,
      Subscription_Plan__c = 'Premium (1,500 THB)'
    );
    insert c;
    // Failed: the recovery flow runs and messages LINE, so give it a stand-in.
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());
    insert new Payment_History__c(
      Contract__c = c.Id,
      Account__c = acc.Id,
      Amount__c = 1500,
      Status__c = 'Failed',
      Failure_Reason__c = 'Card Expired (ERR-02)'
    );
  }

  static Account customer() {
    return [SELECT Id FROM Account WHERE LastName = 'History'];
  }

  @IsTest
  static void accountShowsProductsContractsAndPayments() {
    CustomerHistoryController.History h = CustomerHistoryController.getHistory(
      customer().Id
    );

    Assert.areEqual(customer().Id, h.customerId);
    Assert.areEqual(1, h.products.size());
    Assert.areEqual(1, h.contracts.size());
    Assert.areEqual(1, h.payments.size());
    Assert.areEqual('Failed', h.payments[0].Status__c);
  }

  @IsTest
  static void caseShowsItsAccountHistory() {
    Case c = new Case(AccountId = customer().Id, Subject = 'Filter');
    insert c;

    CustomerHistoryController.History h = CustomerHistoryController.getHistory(
      c.Id
    );

    Assert.areEqual(customer().Id, h.customerId);
    Assert.areEqual(1, h.payments.size());
  }

  @IsTest
  static void newLeadHasEmptyHistory() {
    Lead l = new Lead(LastName = 'New');
    insert l;

    CustomerHistoryController.History h = CustomerHistoryController.getHistory(
      l.Id
    );

    Assert.areEqual(l.Id, h.customerId);
    Assert.isTrue(h.contracts.isEmpty());
    Assert.isTrue(h.payments.isEmpty());
  }
}
