// Puts the demo back to its pre-demo state. Safe to run repeatedly.
// Touches only Somchai Sukhumvit and Meng (the live LINE test friend); other customers are left alone.
// sf apex run --file scripts/apex/reset_demo.apex --target-org noritz

Account somchai = [SELECT Id, LINE_User_ID__c FROM Account WHERE Name = 'Somchai Sukhumvit' LIMIT 1];
Contract contract = [SELECT Id FROM Contract WHERE AccountId = :somchai.Id ORDER BY CreatedDate LIMIT 1];

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
    new Payment_History__c(Contract__c = contract.Id, Account__c = somchai.Id, Amount__c = 1500, Status__c = 'Success'),
    new Payment_History__c(Contract__c = contract.Id, Account__c = somchai.Id, Amount__c = 1500, Status__c = 'Success')
};

Datetime now = System.now();
insert new List<LINE_Message__c>{
    new LINE_Message__c(
        Account__c = somchai.Id,
        LINE_User_ID__c = somchai.LINE_User_ID__c,
        Direction__c = 'Inbound',
        Message_Type__c = 'Text',
        Message_Body__c = 'สวัสดีครับ สนใจเครื่องกรองน้ำ NORITZ แบบรายเดือนครับ มีแพ็กเกจอะไรบ้างครับ',
        Sent_At__c = now.addMinutes(-30)
    ),
    new LINE_Message__c(
        Account__c = somchai.Id,
        LINE_User_ID__c = somchai.LINE_User_ID__c,
        Direction__c = 'Outbound',
        Message_Type__c = 'Text',
        Message_Body__c = 'สวัสดีค่ะคุณสมชาย มี 2 แพ็กเกจค่ะ Standard 900 บาท/เดือน และ Premium 1,500 บาท/เดือน รวมเปลี่ยนไส้กรองฟรีค่ะ',
        Delivery_Status__c = 'Sent',
        Sent_At__c = now.addMinutes(-28)
    ),
    new LINE_Message__c(
        Account__c = somchai.Id,
        LINE_User_ID__c = somchai.LINE_User_ID__c,
        Direction__c = 'Inbound',
        Message_Type__c = 'Text',
        Message_Body__c = 'เอา Premium ครับ',
        Sent_At__c = now.addMinutes(-25)
    )
};

// Meng: the account auto-created when the tester added the OA. Its contract has been
// activated, so it can't go back to Pending Payment or be deleted; reset it to Active.
// Keeps only the "added as a friend" message so the chat shows where the friendship began.
List<Account> mengs = [SELECT Id FROM Account WHERE Name = 'Meng' LIMIT 1];
if (!mengs.isEmpty()) {
    Account meng = mengs[0];
    delete [SELECT Id FROM Payment_History__c WHERE Contract__r.AccountId = :meng.Id];
    delete [
        SELECT Id FROM LINE_Message__c
        WHERE Account__c = :meng.Id AND (Direction__c = 'Outbound' OR Message_Type__c != 'Text')
    ];
    List<LINE_Message__c> inbound = [SELECT Id, Message_Body__c FROM LINE_Message__c WHERE Account__c = :meng.Id];
    List<LINE_Message__c> chatter = new List<LINE_Message__c>();
    for (LINE_Message__c m : inbound) {
        if (m.Message_Body__c != '[Added the OA as a friend]') {
            chatter.add(m);
        }
    }
    delete chatter;

    List<Contract> mengContracts = [SELECT Id, Status FROM Contract WHERE AccountId = :meng.Id];
    for (Contract c : mengContracts) {
        if (c.Status == 'Payment Failed') {
            c.Status = 'Active';
        }
    }
    update mengContracts;

    meng.Customer_Status__c = mengContracts.isEmpty() ? 'Prospect' : 'Active';
    update meng;
}
