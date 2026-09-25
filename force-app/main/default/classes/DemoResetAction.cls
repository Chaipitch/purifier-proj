// "Reset Demo" button on the Contract page: puts the demo customers back to their pre-demo state.
// Safe to run any number of times. Touches only Somchai Sukhumvit and Meng (the live LINE test
// friend); other customers are left alone. scripts/apex/reset_demo.apex calls the same code.
public with sharing class DemoResetAction {
  private static final String FOLLOW_TEXT = '[Added the OA as a friend]';

  @AuraEnabled
  public static void reset() {
    resetSomchai();
    resetMeng();
  }

  private static void resetSomchai() {
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
        'สวัสดีค่ะคุณสมชาย มี 2 แพ็กเกจค่ะ Standard 900 บาท/เดือน และ Premium 1,500 บาท/เดือน รวมเปลี่ยนไส้กรองฟรีค่ะ',
        now.addMinutes(-28)
      ),
      message(somchai, 'Inbound', 'เอา Premium ครับ', now.addMinutes(-25))
    };
  }

  // Meng: the account auto-created when the tester added the OA. Its contract has been
  // activated, so it can't go back to Pending Payment or be deleted; reset it to Active.
  // Keeps only the "added as a friend" message so the chat shows where the friendship began.
  private static void resetMeng() {
    List<Account> accounts = [
      SELECT Id
      FROM Account
      WHERE Name = 'Meng'
      LIMIT 1
    ];
    if (accounts.isEmpty()) {
      return;
    }
    Account meng = accounts[0];

    delete [
      SELECT Id
      FROM Payment_History__c
      WHERE Contract__r.AccountId = :meng.Id
    ];
    List<LINE_Message__c> chatter = new List<LINE_Message__c>();
    for (LINE_Message__c m : [
      SELECT Id, Direction__c, Message_Body__c
      FROM LINE_Message__c
      WHERE Account__c = :meng.Id
    ]) {
      if (m.Direction__c != 'Inbound' || m.Message_Body__c != FOLLOW_TEXT) {
        chatter.add(m);
      }
    }
    delete chatter;

    List<Contract> contracts = [
      SELECT Id, Status
      FROM Contract
      WHERE AccountId = :meng.Id
    ];
    for (Contract c : contracts) {
      if (c.Status == 'Payment Failed') {
        c.Status = 'Active';
      }
    }
    update contracts;

    meng.Customer_Status__c = contracts.isEmpty() ? 'Prospect' : 'Active';
    update meng;
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
