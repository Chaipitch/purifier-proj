// Puts the demo back to its pre-demo state. Safe to run repeatedly.
// Touches only Somchai Sukhumvit's records; other customers are left alone.
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
