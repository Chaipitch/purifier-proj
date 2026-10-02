@IsTest
private class SendFilterReminderActionTest {
  @TestSetup
  static void setup() {
    Id personType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('PersonAccount')
      .getRecordTypeId();
    Account acc = new Account(
      RecordTypeId = personType,
      FirstName = 'Somchai',
      LastName = 'Sukhumvit',
      LINE_User_ID__c = 'U_filter'
    );
    insert acc;
    // Date.valueOf, not newInstance: newInstance reads the year as Buddhist for a th_TH user.
    insert new Assets__c(
      Name = 'NORITZ Pure Water X1',
      Serial_Number__c = 'NZ-2026-9981',
      Account__c = acc.Id,
      Next_Filter_Replacement__c = Date.valueOf('2026-10-07')
    );
  }

  static Assets__c asset() {
    return [SELECT Id, Account__c FROM Assets__c LIMIT 1];
  }

  @IsTest
  static void buttonSendsReminderAndStampsTheAsset() {
    LineCalloutMock mock = new LineCalloutMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    SendFilterReminderAction.Result result = SendFilterReminderAction.sendNow(
      asset().Id
    );
    Test.stopTest();

    Assert.areEqual('Sent', result.status);
    LINE_Message__c msg = [
      SELECT Account__c, Message_Type__c, Message_Body__c, Delivery_Status__c
      FROM LINE_Message__c
    ];
    Assert.areEqual(asset().Account__c, msg.Account__c);
    Assert.areEqual('Filter Reminder', msg.Message_Type__c);
    Assert.areEqual(
      'Hi Somchai,\nThe filter on your NORITZ Pure Water X1 (NZ-2026-9981) is due for replacement on 7 Oct 2026. Reply here to book a technician visit.',
      msg.Message_Body__c
    );
    Assert.isTrue(mock.lastBody.contains('U_filter'));
    Assert.areEqual(
      Date.today(),
      [SELECT Last_Filter_Reminder__c FROM Assets__c LIMIT 1]
      .Last_Filter_Reminder__c
    );
  }

  @IsTest
  static void flowActionQueuesTheReminder() {
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());

    Test.startTest();
    SendFilterReminderAction.send(new List<Id>{ asset().Id });
    Test.stopTest();

    Assert.areEqual(1, [SELECT COUNT() FROM LINE_Message__c]);
  }

  @IsTest
  static void assetWithoutDateGetsNoReminder() {
    Assets__c a = asset();
    a.Next_Filter_Replacement__c = null;
    update a;

    SendFilterReminderAction.Result result = SendFilterReminderAction.sendNow(
      a.Id
    );

    Assert.areEqual('Error', result.status);
    Assert.areEqual(0, [SELECT COUNT() FROM LINE_Message__c]);
  }
}
