@IsTest
private class DemoResetActionTest {
  @TestSetup
  static void setup() {
    Id personType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('PersonAccount')
      .getRecordTypeId();
    Account somchai = new Account(
      RecordTypeId = personType,
      FirstName = 'Somchai',
      LastName = 'Sukhumvit',
      LINE_User_ID__c = 'U_somchai',
      Customer_Status__c = 'Payment Suspended'
    );
    Account meng = new Account(
      RecordTypeId = personType,
      LastName = 'Meng',
      LINE_User_ID__c = 'U_meng',
      Customer_Status__c = 'Payment Suspended'
    );
    Account other = new Account(
      RecordTypeId = personType,
      LastName = 'Other',
      Customer_Status__c = 'Payment Suspended'
    );
    Account newFriend = new Account(
      RecordTypeId = personType,
      LastName = 'New Friend',
      LINE_User_ID__c = 'U_new',
      Customer_Status__c = 'Payment Suspended'
    );
    insert new List<Account>{ somchai, meng, other, newFriend };

    List<Contract> contracts = new List<Contract>();
    for (Account a : new List<Account>{ somchai, meng, other }) {
      contracts.add(
        new Contract(
          AccountId = a.Id,
          Status = 'Pending Payment',
          StartDate = Date.today(),
          ContractTerm = 12,
          Subscription_Plan__c = 'Standard (900 THB)'
        )
      );
    }
    insert contracts;
    // Meng's contract has been through a payment failure.
    contracts[1].Status = 'Payment Failed';
    update contracts[1];

    List<LINE_Message__c> messages = new List<LINE_Message__c>();
    for (Account a : new List<Account>{ somchai, meng, other, newFriend }) {
      messages.add(
        new LINE_Message__c(
          Account__c = a.Id,
          Direction__c = 'Inbound',
          Message_Type__c = 'Text',
          Message_Body__c = '[Added the OA as a friend]'
        )
      );
      messages.add(
        new LINE_Message__c(
          Account__c = a.Id,
          Direction__c = 'Outbound',
          Message_Type__c = 'Payment Retry',
          Message_Body__c = 'retry'
        )
      );
    }
    insert messages;
  }

  @IsTest
  static void resetsSomchaiAndLineFriendsOnly() {
    Test.startTest();
    DemoResetAction.reset();
    Test.stopTest();

    Contract somchaiContract = [
      SELECT
        Status,
        Subscription_Plan__c,
        Stripe_Sub_ID__c,
        Account.Customer_Status__c
      FROM Contract
      WHERE Account.Name = 'Somchai Sukhumvit'
    ];
    Assert.areEqual('Active', somchaiContract.Status);
    Assert.areEqual(
      'Premium (1,500 THB)',
      somchaiContract.Subscription_Plan__c
    );
    Assert.areEqual('sub_demo_12345', somchaiContract.Stripe_Sub_ID__c);
    Assert.areEqual('Active', somchaiContract.Account.Customer_Status__c);
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Payment_History__c
        WHERE Contract__c = :somchaiContract.Id
      ]
    );
    Assert.areEqual(
      3,
      [
        SELECT COUNT()
        FROM LINE_Message__c
        WHERE Account__r.Name = 'Somchai Sukhumvit'
      ]
    );

    List<LINE_Message__c> mengMessages = [
      SELECT Message_Body__c
      FROM LINE_Message__c
      WHERE Account__r.Name = 'Meng'
    ];
    Assert.areEqual(1, mengMessages.size());
    Assert.areEqual(
      '[Added the OA as a friend]',
      mengMessages[0].Message_Body__c
    );
    Assert.areEqual(
      'Active',
      [SELECT Customer_Status__c FROM Account WHERE Name = 'Meng']
      .Customer_Status__c
    );

    Assert.areEqual(
      'Active',
      [SELECT Status FROM Contract WHERE Account.Name = 'Meng'].Status
    );

    // Linked to LINE but no active contract: back to Prospect, chat trimmed.
    Assert.areEqual(
      'Prospect',
      [SELECT Customer_Status__c FROM Account WHERE Name = 'New Friend']
      .Customer_Status__c
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM LINE_Message__c WHERE Account__r.Name = 'New Friend']
    );

    // Not linked to LINE: untouched.
    Assert.areEqual(
      2,
      [SELECT COUNT() FROM LINE_Message__c WHERE Account__r.Name = 'Other']
    );
    Assert.areEqual(
      'Payment Suspended',
      [SELECT Customer_Status__c FROM Account WHERE Name = 'Other']
      .Customer_Status__c
    );
  }

  @IsTest
  static void isSafeToRunTwice() {
    Test.startTest();
    DemoResetAction.reset();
    DemoResetAction.reset();
    Test.stopTest();

    Assert.areEqual(
      3,
      [
        SELECT COUNT()
        FROM LINE_Message__c
        WHERE Account__r.Name = 'Somchai Sukhumvit'
      ]
    );
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Payment_History__c
        WHERE Contract__r.Account.Name = 'Somchai Sukhumvit'
      ]
    );
  }

  @IsTest
  static void explainsWhenSomchaiIsMissing() {
    delete [SELECT Id FROM Contract WHERE Account.Name = 'Somchai Sukhumvit'];
    delete [SELECT Id FROM Account WHERE Name = 'Somchai Sukhumvit'];

    try {
      DemoResetAction.reset();
      Assert.fail('Expected an error');
    } catch (AuraHandledException e) {
      Assert.areEqual(
        'Demo customer Somchai Sukhumvit was not found.',
        e.getMessage()
      );
    }
  }
}
