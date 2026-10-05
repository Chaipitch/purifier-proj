// Puts demo customers back to their pre-demo state. Safe to run any number of times.
// - The "Reset Demo" button (Lead, Account and contract pages) resets only the customer it is
//   pressed on: that lead, that customer, or the customer the contract belongs to.
// - scripts/apex/reset_demo.apex resets everyone: Somchai Sukhumvit (creating his contract and
//   purifier if they are missing), every customer and lead linked to LINE, and customers
//   converted from a LINE lead (they become a fresh lead again).
// Records without a LINE User ID, other than Somchai, are never touched.
public with sharing class DemoResetAction {
  private static final String FOLLOW_TEXT = '[Added the OA as a friend]';
  @TestVisible
  private static final String ARCHIVED_PREFIX = 'Archived - ';
  private static final String OPEN_STATUS = 'Open - Not Contacted';
  @TestVisible
  private static final String SOMCHAI_NAME = 'Somchai Sukhumvit';
  @TestVisible
  private static final String SOMCHAI_SUB_ID = 'sub_demo_12345';
  @TestVisible
  private static final String SOMCHAI_SERIAL = 'NZ-2026-9981';
  @TestVisible
  private static final String NOT_IN_DEMO = 'This record isn\'t linked to LINE, so it isn\'t part of the demo and there is nothing to reset.';

  // Records the reset removed (a converted customer, its contracts and products), each mapped to
  // the fresh lead that replaces the customer.
  private static Map<Id, Id> replacedBy = new Map<Id, Id>();

  // Everyone (the script).
  @AuraEnabled
  public static void reset() {
    Id somchaiId = resetSomchai();
    restoreConvertedLeads(
      [
        SELECT Id, FirstName, LastName, LINE_User_ID__c
        FROM Account
        WHERE Converted_From_LINE_Lead__c = TRUE AND LINE_User_ID__c != NULL
      ]
    );
    resetLineFriends(
      new Map<Id, Account>(
          [
            SELECT Id
            FROM Account
            WHERE LINE_User_ID__c != NULL AND Id != :somchaiId
          ]
        )
        .keySet()
    );
    resetLineLeads(
      [
        SELECT Id
        FROM Lead
        WHERE LINE_User_ID__c != NULL AND IsConverted = FALSE
      ]
    );
  }

  // The button: resets only the customer behind recordId (a Lead, an Account or a contract).
  // Returns the page to open when that record no longer exists (a converted customer is replaced
  // by a fresh lead), or null to reload the same page.
  @AuraEnabled
  public static Id resetFrom(Id recordId) {
    Id customerId = customerBehind(recordId);
    if (customerId == null) {
      throw error('Reset Demo works on a Lead, a customer or a contract.');
    }

    if (customerId.getSObjectType() == Lead.SObjectType) {
      List<Lead> leads = [
        SELECT Id
        FROM Lead
        WHERE Id = :customerId AND LINE_User_ID__c != NULL
      ];
      if (leads.isEmpty()) {
        throw error(NOT_IN_DEMO);
      }
      resetLineLeads(leads);
      return null;
    }

    Account customer = [
      SELECT
        Id,
        Name,
        FirstName,
        LastName,
        LINE_User_ID__c,
        Converted_From_LINE_Lead__c
      FROM Account
      WHERE Id = :customerId
    ];
    if (customer.Name == SOMCHAI_NAME) {
      resetSomchai();
      return null;
    }
    if (customer.LINE_User_ID__c == null) {
      throw error(NOT_IN_DEMO);
    }
    if (customer.Converted_From_LINE_Lead__c) {
      restoreConvertedLeads(new List<Account>{ customer });
      return replacedBy.containsKey(recordId)
        ? replacedBy.get(recordId)
        : replacedBy.get(customerId);
    }
    resetLineFriends(new Set<Id>{ customerId });
    return null;
  }

  // The Lead or Account a record belongs to: a converted lead's customer, a contract's customer
  // (or its lead before conversion). Null for anything else.
  private static Id customerBehind(Id recordId) {
    if (recordId == null) {
      return null;
    }
    SObjectType type = recordId.getSObjectType();
    if (type == Account.SObjectType) {
      return recordId;
    }
    if (type == Lead.SObjectType) {
      Lead l = [
        SELECT Id, IsConverted, ConvertedAccountId
        FROM Lead
        WHERE Id = :recordId
      ];
      return l.IsConverted && l.ConvertedAccountId != null
        ? l.ConvertedAccountId
        : l.Id;
    }
    if (type == Contracts__c.SObjectType) {
      Contracts__c c = [
        SELECT Account__c, Lead__c
        FROM Contracts__c
        WHERE Id = :recordId
      ];
      return c.Account__c != null ? c.Account__c : c.Lead__c;
    }
    return null;
  }

  // A conversion can't be undone. So each customer converted from a LINE lead is deleted, with
  // its contracts (and their payments), products and chat, and a fresh lead with the same LINE
  // account and name takes its place: the next run starts from a brand-new lead again. If
  // Salesforce won't delete an account, it is archived instead (renamed, LINE id cleared).
  private static void restoreConvertedLeads(List<Account> converted) {
    if (converted.isEmpty()) {
      return;
    }

    Map<Id, Id> customerOf = new Map<Id, Id>();
    List<Contracts__c> contracts = [
      SELECT Id, Account__c
      FROM Contracts__c
      WHERE Account__c IN :converted
    ];
    for (Contracts__c c : contracts) {
      customerOf.put(c.Id, c.Account__c);
    }
    List<Assets__c> assets = [
      SELECT Id, Account__c
      FROM Assets__c
      WHERE Account__c IN :converted
    ];
    for (Assets__c a : assets) {
      customerOf.put(a.Id, a.Account__c);
    }
    delete contracts; // their payments go with them (master-detail)
    delete assets;
    delete [SELECT Id FROM LINE_Message__c WHERE Account__c IN :converted];

    List<Account> archived = new List<Account>();
    List<Database.DeleteResult> results = Database.delete(converted, false);
    for (Integer i = 0; i < converted.size(); i++) {
      if (!results[i].isSuccess()) {
        Account a = converted[i];
        archived.add(
          new Account(
            Id = a.Id,
            LastName = ARCHIVED_PREFIX + a.LastName,
            LINE_User_ID__c = null,
            Converted_From_LINE_Lead__c = false
          )
        );
      }
    }
    update archived;

    Map<Id, Lead> freshByCustomer = new Map<Id, Lead>();
    for (Account a : converted) {
      customerOf.put(a.Id, a.Id);
      freshByCustomer.put(
        a.Id,
        new Lead(
          FirstName = a.FirstName,
          LastName = a.LastName,
          LINE_User_ID__c = a.LINE_User_ID__c,
          LeadSource = 'LINE',
          Status = OPEN_STATUS
        )
      );
    }
    insert freshByCustomer.values();
    for (Id removed : customerOf.keySet()) {
      replacedBy.put(removed, freshByCustomer.get(customerOf.get(removed)).Id);
    }

    List<LINE_Message__c> follows = new List<LINE_Message__c>();
    for (Lead l : freshByCustomer.values()) {
      follows.add(
        new LINE_Message__c(
          Lead__c = l.Id,
          LINE_User_ID__c = l.LINE_User_ID__c,
          Direction__c = 'Inbound',
          Message_Type__c = 'Text',
          Message_Body__c = FOLLOW_TEXT,
          Sent_At__c = System.now()
        )
      );
    }
    insert follows;
  }

  // Open LINE leads go back to how a brand-new LINE friend looks: chat trimmed to the "added as a
  // friend" line, no plan, subscription or filter date, no contracts or products recorded against
  // them, and Open - Not Contacted.
  private static void resetLineLeads(List<Lead> leads) {
    if (leads.isEmpty()) {
      return;
    }
    List<LINE_Message__c> chatter = new List<LINE_Message__c>();
    for (LINE_Message__c m : [
      SELECT Id, Direction__c, Message_Body__c
      FROM LINE_Message__c
      WHERE Lead__c IN :leads AND Account__c = NULL
    ]) {
      if (m.Direction__c != 'Inbound' || m.Message_Body__c != FOLLOW_TEXT) {
        chatter.add(m);
      }
    }
    delete chatter;
    // Before the lead update: the Lead highlight panel flow would copy a contract's plan back.
    delete [
      SELECT Id
      FROM Contracts__c
      WHERE Lead__c IN :leads AND Account__c = NULL
    ];
    delete [
      SELECT Id
      FROM Assets__c
      WHERE Lead__c IN :leads AND Account__c = NULL
    ];
    for (Lead l : leads) {
      l.Status = OPEN_STATUS;
      l.Subscription_Plan__c = null;
      l.Stripe_Sub_ID__c = null;
      l.Next_Filter_Date__c = null;
    }
    update leads;
  }

  private static Id resetSomchai() {
    List<Account> accounts = [
      SELECT Id, LINE_User_ID__c
      FROM Account
      WHERE Name = :SOMCHAI_NAME
      LIMIT 1
    ];
    if (accounts.isEmpty()) {
      throw error('Demo customer Somchai Sukhumvit was not found.');
    }
    Account somchai = accounts[0];
    Date today = Date.today();

    // Created on the first run, restored on every run after that.
    List<Contracts__c> contracts = [
      SELECT Id
      FROM Contracts__c
      WHERE Stripe_Sub_ID__c = :SOMCHAI_SUB_ID
      ORDER BY CreatedDate
      LIMIT 1
    ];
    Contracts__c contract = contracts.isEmpty()
      ? new Contracts__c()
      : contracts[0];
    if (contract.Id != null) {
      delete [
        SELECT Id
        FROM Payment_History__c
        WHERE Subscription_Contract__c = :contract.Id
      ];
    }
    delete [SELECT Id FROM LINE_Message__c WHERE Account__c = :somchai.Id];

    Date startDate = GregorianDates.addMonths(today, -3);
    contract.Account__c = somchai.Id;
    contract.Status__c = 'Active';
    contract.Subscription_Plan__c = 'Premium (1,500 THB)';
    contract.Stripe_Sub_ID__c = SOMCHAI_SUB_ID;
    contract.Contract_Start_Date__c = startDate;
    contract.Contract_Term_months__c = 12;
    contract.Contract_End_Date__c = GregorianDates.addMonths(startDate, 12);
    contract.Next_Billing_Date__c = GregorianDates.startOfMonth(today);
    upsert contract;

    List<Assets__c> assets = [
      SELECT Id
      FROM Assets__c
      WHERE Serial_Number__c = :SOMCHAI_SERIAL
      ORDER BY CreatedDate
      LIMIT 1
    ];
    Assets__c purifier = assets.isEmpty() ? new Assets__c() : assets[0];
    purifier.Name = 'NORITZ Pure Water X1';
    purifier.Serial_Number__c = SOMCHAI_SERIAL;
    purifier.Account__c = somchai.Id;
    purifier.Status__c = 'Installed';
    purifier.Install_Date__c = startDate;
    purifier.Next_Filter_Replacement__c = today.addDays(14);
    purifier.Last_Filter_Reminder__c = null;
    upsert purifier;

    somchai.Customer_Status__c = 'Active';
    update somchai;

    // Seeded history: don't let the payment success flow message the customer about it.
    SendPaymentSuccessAction.suppress = true;
    insert new List<Payment_History__c>{
      payment(contract.Id, somchai.Id),
      payment(contract.Id, somchai.Id)
    };
    SendPaymentSuccessAction.suppress = false;

    Datetime now = System.now();
    insert new List<LINE_Message__c>{
      message(
        somchai,
        'Inbound',
        'สวัสดีครับ สนใจเครื่องกรองน้ำ NORITZ แบบรายเดือนครับ มีแพ็กเกจอะไรบ้างครับ',
        now.addMinutes(-30)
      ),
      message(
        somchai,
        'Outbound',
        'สวัสดีค่ะคุณ Somchai มี 2 แพ็กเกจค่ะ Standard 900 บาท/เดือน และ Premium 1,500 บาท/เดือน รวมเปลี่ยนไส้กรองฟรีค่ะ',
        now.addMinutes(-28)
      ),
      message(somchai, 'Inbound', 'เอา Premium ครับ', now.addMinutes(-25))
    };
    return somchai.Id;
  }

  // Other customers with a LINE User ID (for example people who added the OA while testing).
  // Payments and chat are cleared except the "added as a friend" line. Payment Failed contracts
  // go back to Active. The customer is Active if they have an Active contract, otherwise Prospect.
  private static void resetLineFriends(Set<Id> friendIds) {
    if (friendIds.isEmpty()) {
      return;
    }

    delete [
      SELECT Id
      FROM Payment_History__c
      WHERE Subscription_Contract__r.Account__c IN :friendIds
    ];
    List<LINE_Message__c> chatter = new List<LINE_Message__c>();
    for (LINE_Message__c m : [
      SELECT Id, Direction__c, Message_Body__c
      FROM LINE_Message__c
      WHERE Account__c IN :friendIds
    ]) {
      if (m.Direction__c != 'Inbound' || m.Message_Body__c != FOLLOW_TEXT) {
        chatter.add(m);
      }
    }
    delete chatter;

    List<Contracts__c> contracts = [
      SELECT Id, Account__c, Status__c
      FROM Contracts__c
      WHERE Account__c IN :friendIds
    ];
    Set<Id> withActiveContract = new Set<Id>();
    for (Contracts__c c : contracts) {
      if (c.Status__c == 'Payment Failed') {
        c.Status__c = 'Active';
      }
      if (c.Status__c == 'Active') {
        withActiveContract.add(c.Account__c);
      }
    }
    update contracts;

    List<Account> friends = new List<Account>();
    for (Id friendId : friendIds) {
      friends.add(
        new Account(
          Id = friendId,
          Customer_Status__c = withActiveContract.contains(friendId)
            ? 'Active'
            : 'Prospect'
        )
      );
    }
    update friends;
  }

  // setMessage so tests and logs see the text, not "Script-thrown exception".
  private static AuraHandledException error(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }

  private static Payment_History__c payment(Id contractId, Id accountId) {
    return new Payment_History__c(
      Subscription_Contract__c = contractId,
      Account__c = accountId,
      Amount__c = 1500,
      Status__c = 'Success'
    );
  }

  private static LINE_Message__c message(
    Account account,
    String direction,
    String body,
    Datetime sentAt
  ) {
    return new LINE_Message__c(
      Account__c = account.Id,
      LINE_User_ID__c = account.LINE_User_ID__c,
      Direction__c = direction,
      Message_Type__c = 'Text',
      Message_Body__c = body,
      Delivery_Status__c = direction == 'Outbound' ? 'Sent' : null,
      Sent_At__c = sentAt
    );
  }
}
