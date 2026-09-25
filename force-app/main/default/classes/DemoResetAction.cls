// "Reset Demo" button on the Contract page: puts the demo customers back to their pre-demo state.
// Safe to run any number of times. Touches Somchai Sukhumvit and every customer linked to LINE;
// customers without a LINE User ID are left alone. scripts/apex/reset_demo.apex calls the same code.
public with sharing class DemoResetAction {
  private static final String FOLLOW_TEXT = '[Added the OA as a friend]';

  @AuraEnabled
  public static void reset() {
    Id somchaiId = resetSomchai();
    resetLineFriends(somchaiId);
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
    List<Contract> contracts = [
      SELECT Id
      FROM Contract
      WHERE AccountId = :somchai.Id
      ORDER BY CreatedDate
      LIMIT 1
    ];
    if (contracts.isEmpty()) {
      throw error('Somchai Sukhumvit has no contract.');
    }
    Contract contract = contracts[0];

    delete [SELECT Id FROM Payment_History__c WHERE Contract__c = :contract.Id];
    delete [SELECT Id FROM LINE_Message__c WHERE Account__c = :somchai.Id];

    // Pending Payment -> Active and Payment Failed -> Active are both allowed; Active can never
    // go back to Pending Payment, so the reset state is Active.
    contract.Status = 'Active';
    contract.Subscription_Plan__c = 'Premium (1,500 THB)';
    contract.Stripe_Sub_ID__c = 'sub_demo_12345';
    // Not toStartOfMonth(): for a th_TH user it rebuilds the date from the Buddhist year and saves 2569.
    Date today = Date.today();
    contract.Next_Billing_Date__c = today.addDays(1 - today.day());
    update contract;

    somchai.Customer_Status__c = 'Active';
    update somchai;

    insert new List<Payment_History__c>{
      payment(contract.Id, somchai.Id),
      payment(contract.Id, somchai.Id)
    };

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
  // go back to Active: an activated contract can't return to Pending Payment or be deleted.
  // The customer is Active if they have an Active contract, otherwise Prospect.
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
      WHERE Contract__r.AccountId IN :friendIds
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

    List<Contract> contracts = [
      SELECT Id, AccountId, Status
      FROM Contract
      WHERE AccountId IN :friendIds
    ];
    Set<Id> withActiveContract = new Set<Id>();
    for (Contract c : contracts) {
      if (c.Status == 'Payment Failed') {
        c.Status = 'Active';
      }
      if (c.Status == 'Active') {
        withActiveContract.add(c.AccountId);
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
      Contract__c = contractId,
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
