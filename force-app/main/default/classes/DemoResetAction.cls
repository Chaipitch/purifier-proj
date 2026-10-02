// "Reset Demo" button on the contract (Contracts__c) page: puts the demo customers back to their
// pre-demo state, creating Somchai's contract and purifier if they are missing. Safe to run any
// number of times. Touches Somchai Sukhumvit, every customer and lead linked to
// LINE, and customers converted from a LINE lead (they become a fresh lead again). Records without
// a LINE User ID are left alone. scripts/apex/reset_demo.apex calls the same code.
public with sharing class DemoResetAction {
  private static final String FOLLOW_TEXT = '[Added the OA as a friend]';
  @TestVisible
  private static final String ARCHIVED_PREFIX = 'Archived - ';
  private static final String OPEN_STATUS = 'Open - Not Contacted';
  @TestVisible
  private static final String SOMCHAI_SUB_ID = 'sub_demo_12345';
  @TestVisible
  private static final String SOMCHAI_SERIAL = 'NZ-2026-9981';

  @AuraEnabled
  public static void reset() {
    Id somchaiId = resetSomchai();
    restoreConvertedLeads();
    resetLineFriends(somchaiId);
    resetLineLeads();
  }

  // A conversion can't be undone. So the converted customer is archived (renamed, LINE id
  // cleared) and a new lead with the same LINE id, name and plan takes its place: the next run
  // starts from a lead again.
  private static void restoreConvertedLeads() {
    List<Account> converted = [
      SELECT Id, FirstName, LastName, LINE_User_ID__c
      FROM Account
      WHERE Converted_From_LINE_Lead__c = TRUE AND LINE_User_ID__c != NULL
    ];
    if (converted.isEmpty()) {
      return;
    }
    Map<Id, Lead> originalByAccount = new Map<Id, Lead>();
    for (Lead l : [
      SELECT ConvertedAccountId, Subscription_Plan__c
      FROM Lead
      WHERE ConvertedAccountId IN :converted
    ]) {
      originalByAccount.put(l.ConvertedAccountId, l);
    }

    List<Lead> fresh = new List<Lead>();
    for (Account a : converted) {
      Lead original = originalByAccount.get(a.Id);
      fresh.add(
        new Lead(
          FirstName = a.FirstName,
          LastName = a.LastName,
          LINE_User_ID__c = a.LINE_User_ID__c,
          LeadSource = 'LINE',
          Subscription_Plan__c = original?.Subscription_Plan__c
        )
      );
      a.LastName = ARCHIVED_PREFIX + a.LastName;
      a.LINE_User_ID__c = null;
      a.Converted_From_LINE_Lead__c = false;
    }
    update converted;
    insert fresh;

    List<LINE_Message__c> follows = new List<LINE_Message__c>();
    for (Lead l : fresh) {
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

  // Open LINE leads: chat back to the "added as a friend" line, status back to the start.
  private static void resetLineLeads() {
    List<Lead> leads = [
      SELECT Id
      FROM Lead
      WHERE LINE_User_ID__c != NULL AND IsConverted = FALSE
    ];
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
    for (Lead l : leads) {
      l.Status = OPEN_STATUS;
    }
    update leads;
  }

  private static Id resetSomchai() {
    List<Account> accounts = [
      SELECT Id, LINE_User_ID__c
      FROM Account
      WHERE Name = 'Somchai Sukhumvit'
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

  // Everyone else with a LINE User ID (for example people who added the OA while testing).
  // Payments and chat are cleared except the "added as a friend" line. Payment Failed contracts
  // go back to Active. The customer is Active if they have an Active contract, otherwise Prospect.
  private static void resetLineFriends(Id somchaiId) {
    Map<Id, Account> friends = new Map<Id, Account>(
      [
        SELECT Id
        FROM Account
        WHERE LINE_User_ID__c != NULL AND Id != :somchaiId
      ]
    );
    if (friends.isEmpty()) {
      return;
    }
    Set<Id> friendIds = friends.keySet();

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

    for (Account a : friends.values()) {
      a.Customer_Status__c = withActiveContract.contains(a.Id)
        ? 'Active'
        : 'Prospect';
    }
    update friends.values();
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
