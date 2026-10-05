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

    List<Contracts__c> contracts = new List<Contracts__c>();
    for (Account a : new List<Account>{ somchai, meng, other }) {
      contracts.add(
        new Contracts__c(
          Account__c = a.Id,
          Status__c = 'Pending Payment',
          Contract_Start_Date__c = Date.today(),
          Contract_Term_months__c = 12,
          Subscription_Plan__c = 'Standard (900 THB)'
        )
      );
    }
    // Somchai's demo contract mid-demo: failed payment, wrong plan.
    contracts[0].Stripe_Sub_ID__c = DemoResetAction.SOMCHAI_SUB_ID;
    contracts[0].Status__c = 'Payment Failed';
    // Meng's contract has been through a payment failure.
    contracts[1].Status__c = 'Payment Failed';
    insert contracts;

    insert new Assets__c(
      Name = 'NORITZ Pure Water X1',
      Serial_Number__c = DemoResetAction.SOMCHAI_SERIAL,
      Account__c = somchai.Id,
      Next_Filter_Replacement__c = Date.today().addDays(-3),
      Last_Filter_Reminder__c = Date.today()
    );

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

    Contracts__c somchaiContract = [
      SELECT
        Status__c,
        Subscription_Plan__c,
        Stripe_Sub_ID__c,
        Account__r.Customer_Status__c
      FROM Contracts__c
      WHERE Account__r.Name = 'Somchai Sukhumvit'
    ];
    Assert.areEqual('Active', somchaiContract.Status__c);
    Assert.areEqual(
      'Premium (1,500 THB)',
      somchaiContract.Subscription_Plan__c
    );
    Assert.areEqual('sub_demo_12345', somchaiContract.Stripe_Sub_ID__c);
    Assert.areEqual('Active', somchaiContract.Account__r.Customer_Status__c);
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM Payment_History__c
        WHERE Subscription_Contract__c = :somchaiContract.Id
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
    Assets__c purifier = [
      SELECT Next_Filter_Replacement__c, Last_Filter_Reminder__c
      FROM Assets__c
      WHERE Account__r.Name = 'Somchai Sukhumvit'
    ];
    Assert.areEqual(
      Date.today().addDays(14),
      purifier.Next_Filter_Replacement__c
    );
    Assert.isNull(purifier.Last_Filter_Reminder__c);

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
      [SELECT Status__c FROM Contracts__c WHERE Account__r.Name = 'Meng']
      .Status__c
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
        WHERE Subscription_Contract__r.Account__r.Name = 'Somchai Sukhumvit'
      ]
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Contracts__c
        WHERE Account__r.Name = 'Somchai Sukhumvit'
      ]
    );
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM Assets__c
        WHERE Account__r.Name = 'Somchai Sukhumvit'
      ]
    );
  }

  // First run in a fresh org: Somchai's contract and purifier are created.
  @IsTest
  static void createsSomchaisContractAndPurifierWhenMissing() {
    delete [
      SELECT Id
      FROM Contracts__c
      WHERE Account__r.Name = 'Somchai Sukhumvit'
    ];
    delete [
      SELECT Id
      FROM Assets__c
      WHERE Account__r.Name = 'Somchai Sukhumvit'
    ];

    Test.startTest();
    DemoResetAction.reset();
    Test.stopTest();

    Contracts__c c = [
      SELECT Status__c, Stripe_Sub_ID__c, Subscription_Plan__c
      FROM Contracts__c
      WHERE Account__r.Name = 'Somchai Sukhumvit'
    ];
    Assert.areEqual('Active', c.Status__c);
    Assert.areEqual('sub_demo_12345', c.Stripe_Sub_ID__c);
    Assert.areEqual('Premium (1,500 THB)', c.Subscription_Plan__c);
    Assets__c a = [
      SELECT Name, Serial_Number__c, Next_Filter_Replacement__c
      FROM Assets__c
      WHERE Account__r.Name = 'Somchai Sukhumvit'
    ];
    Assert.areEqual('NORITZ Pure Water X1', a.Name);
    Assert.areEqual('NZ-2026-9981', a.Serial_Number__c);
    Assert.areEqual(Date.today().addDays(14), a.Next_Filter_Replacement__c);
  }

  @IsTest
  static void explainsWhenSomchaiIsMissing() {
    delete [
      SELECT Id
      FROM Contracts__c
      WHERE Account__r.Name = 'Somchai Sukhumvit'
    ];
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

  @IsTest
  static void convertedLeadComesBackAsAFreshLead() {
    Lead l = new Lead(
      FirstName = 'Somying',
      LastName = 'Jaidee',
      LINE_User_ID__c = 'U_conv',
      Subscription_Plan__c = 'Standard (900 THB)'
    );
    insert l;
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());
    Id accountId = LeadConversionService.convertOnFirstPayment(l.Id);

    Test.startTest();
    DemoResetAction.reset();
    Test.stopTest();

    // Deleted with its contracts, products and chat. If the org refuses to delete the account,
    // it must at least be archived and unlinked from LINE.
    List<Account> left = [
      SELECT LastName, LINE_User_ID__c
      FROM Account
      WHERE Id = :accountId
    ];
    if (!left.isEmpty()) {
      Assert.areEqual('Archived - Jaidee', left[0].LastName);
      Assert.isNull(left[0].LINE_User_ID__c);
    }
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Contracts__c WHERE Account__c = :accountId]
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM LINE_Message__c WHERE Account__c = :accountId]
    );

    Lead fresh = [
      SELECT FirstName, LastName, Subscription_Plan__c, IsConverted, Status
      FROM Lead
      WHERE LINE_User_ID__c = 'U_conv' AND IsConverted = FALSE
    ];
    Assert.areEqual('Somying', fresh.FirstName);
    Assert.areEqual('Jaidee', fresh.LastName);
    Assert.isNull(fresh.Subscription_Plan__c, 'A fresh lead has no plan yet');
    Assert.areEqual('Open - Not Contacted', fresh.Status);
    Assert.isFalse(fresh.IsConverted);
    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM LINE_Message__c
        WHERE Lead__c = :fresh.Id AND Account__c = NULL
      ]
    );
  }

  // The button pressed on a converted customer's page (or its contract) opens the fresh lead.
  @IsTest
  static void buttonOnAConvertedCustomerOpensTheFreshLead() {
    Lead l = new Lead(
      FirstName = 'Somying',
      LastName = 'Jaidee',
      LINE_User_ID__c = 'U_conv',
      Subscription_Plan__c = 'Standard (900 THB)'
    );
    insert l;
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());
    Id accountId = LeadConversionService.convertOnFirstPayment(l.Id);
    Id contractId = [SELECT Id FROM Contracts__c WHERE Account__c = :accountId]
    .Id;

    Test.startTest();
    Id opened = DemoResetAction.resetFrom(contractId);
    Test.stopTest();

    Assert.areEqual(
      [
        SELECT Id
        FROM Lead
        WHERE LINE_User_ID__c = 'U_conv' AND IsConverted = FALSE
      ]
      .Id,
      opened
    );
  }

  // The button resets only the customer it is pressed on.
  @IsTest
  static void buttonOnSomchaiResetsOnlySomchai() {
    Id somchaiId = [SELECT Id FROM Account WHERE Name = 'Somchai Sukhumvit'].Id;

    Assert.isNull(DemoResetAction.resetFrom(somchaiId), 'Reloads the page');

    Assert.areEqual(
      'Active',
      [SELECT Customer_Status__c FROM Account WHERE Id = :somchaiId]
      .Customer_Status__c
    );
    Assert.areEqual(
      'Payment Suspended',
      [SELECT Customer_Status__c FROM Account WHERE Name = 'Meng']
      .Customer_Status__c,
      'Other LINE customers are left alone'
    );
  }

  @IsTest
  static void buttonOnALineCustomerResetsOnlyThem() {
    Id mengId = [SELECT Id FROM Account WHERE Name = 'Meng'].Id;

    Assert.isNull(DemoResetAction.resetFrom(mengId));

    Assert.areEqual(
      'Active',
      [SELECT Customer_Status__c FROM Account WHERE Id = :mengId]
      .Customer_Status__c
    );
    Assert.areEqual(
      'Active',
      [SELECT Status__c FROM Contracts__c WHERE Account__c = :mengId].Status__c
    );
    Assert.areEqual(
      1,
      [SELECT COUNT() FROM LINE_Message__c WHERE Account__c = :mengId]
    );
    Assert.areEqual(
      'Payment Suspended',
      [SELECT Customer_Status__c FROM Account WHERE Name = 'Somchai Sukhumvit']
      .Customer_Status__c,
      'Somchai is left alone'
    );
    Assert.areEqual(
      2,
      [
        SELECT COUNT()
        FROM LINE_Message__c
        WHERE Account__r.Name = 'New Friend'
      ],
      'Other LINE customers are left alone'
    );
  }

  @IsTest
  static void buttonOnALeadResetsOnlyThatLead() {
    Lead pressed = new Lead(
      LastName = 'Pressed',
      LINE_User_ID__c = 'U_pressed',
      Status = 'Working - Contacted',
      Subscription_Plan__c = 'Premium (1,500 THB)'
    );
    Lead other = new Lead(
      LastName = 'Other Lead',
      LINE_User_ID__c = 'U_other',
      Status = 'Working - Contacted',
      Subscription_Plan__c = 'Standard (900 THB)'
    );
    insert new List<Lead>{ pressed, other };

    Assert.isNull(DemoResetAction.resetFrom(pressed.Id));

    Lead reset = [
      SELECT Status, Subscription_Plan__c
      FROM Lead
      WHERE Id = :pressed.Id
    ];
    Assert.areEqual('Open - Not Contacted', reset.Status);
    Assert.isNull(reset.Subscription_Plan__c);
    Lead untouched = [
      SELECT Status, Subscription_Plan__c
      FROM Lead
      WHERE Id = :other.Id
    ];
    Assert.areEqual('Working - Contacted', untouched.Status);
    Assert.areEqual('Standard (900 THB)', untouched.Subscription_Plan__c);
  }

  @IsTest
  static void buttonOutsideTheDemoExplains() {
    Id otherId = [SELECT Id FROM Account WHERE Name = 'Other'].Id;

    try {
      DemoResetAction.resetFrom(otherId);
      Assert.fail('Expected an error');
    } catch (AuraHandledException e) {
      Assert.areEqual(DemoResetAction.NOT_IN_DEMO, e.getMessage());
    }
    Assert.areEqual(
      'Payment Suspended',
      [SELECT Customer_Status__c FROM Account WHERE Id = :otherId]
      .Customer_Status__c
    );
  }

  @IsTest
  static void openLineLeadIsLikeANewFriendAgain() {
    Lead l = new Lead(
      LastName = 'Chatty',
      LINE_User_ID__c = 'U_chatty',
      Status = 'Working - Contacted',
      Subscription_Plan__c = 'Premium (1,500 THB)',
      Stripe_Sub_ID__c = 'sub_demo_chatty'
    );
    insert l;
    insert new Contracts__c(
      Lead__c = l.Id,
      Status__c = 'Pending Payment',
      Subscription_Plan__c = 'Premium (1,500 THB)'
    );
    insert new Assets__c(Name = 'NORITZ Pure Water X1', Lead__c = l.Id);
    insert new List<LINE_Message__c>{
      new LINE_Message__c(
        Lead__c = l.Id,
        Direction__c = 'Inbound',
        Message_Body__c = '[Added the OA as a friend]'
      ),
      new LINE_Message__c(
        Lead__c = l.Id,
        Direction__c = 'Outbound',
        Message_Body__c = 'checkout'
      )
    };

    DemoResetAction.reset();

    Assert.areEqual(
      1,
      [SELECT COUNT() FROM LINE_Message__c WHERE Lead__c = :l.Id]
    );
    Lead saved = [
      SELECT Status, Subscription_Plan__c, Stripe_Sub_ID__c
      FROM Lead
      WHERE Id = :l.Id
    ];
    Assert.areEqual('Open - Not Contacted', saved.Status);
    Assert.isNull(saved.Subscription_Plan__c);
    Assert.isNull(saved.Stripe_Sub_ID__c);
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Contracts__c WHERE Lead__c = :l.Id]
    );
    Assert.areEqual(0, [SELECT COUNT() FROM Assets__c WHERE Lead__c = :l.Id]);
  }
}
