@IsTest
private class LineInboundNotificationsTest {
  @IsTest
  static void inboundMessageNotifiesTheLeadOwner() {
    Lead l = new Lead(LastName = 'Friend', LINE_User_ID__c = 'U_notify');
    insert l;

    Test.startTest();
    insert new LINE_Message__c(
      Lead__c = l.Id,
      Direction__c = 'Inbound',
      Message_Body__c = 'Hello, is the Premium plan available?'
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    Assert.areEqual(1, LineInboundNotifications.sent.size());
  }

  @IsTest
  static void outboundMessageSendsNoNotification() {
    Lead l = new Lead(LastName = 'Friend', LINE_User_ID__c = 'U_notify');
    insert l;

    Test.startTest();
    insert new LINE_Message__c(
      Lead__c = l.Id,
      Direction__c = 'Outbound',
      Message_Body__c = 'Hi from NORITZ'
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    Assert.areEqual(0, LineInboundNotifications.sent.size());
  }

  @IsTest
  static void accountMessageNotifiesTheAccountOwner() {
    Account acc = new Account(Name = 'Customer');
    insert acc;
    LINE_Message__c m = new LINE_Message__c(
      Account__c = acc.Id,
      Direction__c = 'Inbound',
      Message_Body__c = 'x'.repeat(300)
    );
    insert m;

    LineInboundNotifications.notifyOwners(new Set<Id>{ m.Id });

    Assert.areEqual(1, LineInboundNotifications.sent.size());
  }
}
