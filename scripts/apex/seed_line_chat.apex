// Resets Somchai's LINE chat to the demo history. Safe to run repeatedly.
// sf apex run --file scripts/apex/seed_line_chat.apex --target-org noritz

Account somchai = [SELECT Id, LINE_User_ID__c FROM Account WHERE Name = 'Somchai Sukhumvit' LIMIT 1];

delete [SELECT Id FROM LINE_Message__c WHERE Account__c = :somchai.Id];

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
