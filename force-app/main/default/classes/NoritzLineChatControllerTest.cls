@IsTest
private class NoritzLineChatControllerTest {
  @TestSetup
  static void setup() {
    Id personType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('PersonAccount')
      .getRecordTypeId();
    insert new Account(
      RecordTypeId = personType,
      FirstName = 'Test',
      LastName = 'Customer',
      LINE_User_ID__c = 'U_test_123'
    );
  }

  static Account customer() {
    return [
      SELECT Id, LINE_User_ID__c
      FROM Account
      WHERE LastName = 'Customer'
    ];
  }

  @IsTest
  static void getChatReturnsMessagesOldestFirst() {
    Id accountId = customer().Id;
    Datetime base = System.now();
    insert new List<LINE_Message__c>{
      new LINE_Message__c(
        Account__c = accountId,
        Direction__c = 'Outbound',
        Message_Body__c = 'second',
        Sent_At__c = base
      ),
      new LINE_Message__c(
        Account__c = accountId,
        Direction__c = 'Inbound',
        Message_Body__c = 'first',
        Sent_At__c = base.addMinutes(-5)
      )
    };

    NoritzLineChatController.ChatData data = NoritzLineChatController.getChat(
      accountId
    );

    Assert.areEqual('Test Customer', data.customerName);
    Assert.areEqual('U_test_123', data.lineUserId);
    Assert.areEqual(2, data.messages.size());
    Assert.areEqual('first', data.messages[0].Message_Body__c);
    Assert.areEqual('second', data.messages[1].Message_Body__c);
  }

  @IsTest
  static void getChatKeepsOnlyNewest50() {
    Id accountId = customer().Id;
    Datetime base = System.now();
    List<LINE_Message__c> msgs = new List<LINE_Message__c>();
    for (Integer i = 0; i < 55; i++) {
      msgs.add(
        new LINE_Message__c(
          Account__c = accountId,
          Direction__c = 'Inbound',
          Message_Body__c = 'm' + i,
          Sent_At__c = base.addSeconds(i)
        )
      );
    }
    insert msgs;

    List<LINE_Message__c> shown = NoritzLineChatController.getChat(accountId)
      .messages;

    Assert.areEqual(50, shown.size());
    Assert.areEqual('m5', shown[0].Message_Body__c);
    Assert.areEqual('m54', shown[49].Message_Body__c);
  }

  private class LineMock implements HttpCalloutMock {
    Integer status;
    String lastBody;
    LineMock(Integer status) {
      this.status = status;
    }
    public HttpResponse respond(HttpRequest req) {
      lastBody = req.getBody();
      HttpResponse res = new HttpResponse();
      res.setStatusCode(status);
      res.setBody(status == 200 ? '{}' : '{"message":"Authentication failed"}');
      return res;
    }
  }

  @IsTest
  static void sendMessagePushesToLineThenSaves() {
    Id accountId = customer().Id;
    LineMock mock = new LineMock(200);
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    LINE_Message__c saved = NoritzLineChatController.sendMessage(
      accountId,
      '  Hello Somchai  '
    );
    Test.stopTest();

    LINE_Message__c row = [
      SELECT
        Direction__c,
        Message_Body__c,
        Message_Type__c,
        LINE_User_ID__c,
        Delivery_Status__c,
        Delivery_Error__c
      FROM LINE_Message__c
      WHERE Id = :saved.Id
    ];
    Assert.areEqual('Outbound', row.Direction__c);
    Assert.areEqual('Hello Somchai', row.Message_Body__c);
    Assert.areEqual('Text', row.Message_Type__c);
    Assert.areEqual('U_test_123', row.LINE_User_ID__c);
    Assert.areEqual('Sent', row.Delivery_Status__c);
    Assert.isNull(row.Delivery_Error__c);
    Assert.isTrue(mock.lastBody.contains('"to":"U_test_123"'));
    Assert.isTrue(mock.lastBody.contains('"text":"Hello Somchai"'));
  }

  @IsTest
  static void sendMessageKeepsFailedPushWithReason() {
    Test.setMock(HttpCalloutMock.class, new LineMock(401));

    Test.startTest();
    LINE_Message__c saved = NoritzLineChatController.sendMessage(
      customer().Id,
      'Hello'
    );
    Test.stopTest();

    LINE_Message__c row = [
      SELECT Delivery_Status__c, Delivery_Error__c
      FROM LINE_Message__c
      WHERE Id = :saved.Id
    ];
    Assert.areEqual('Failed', row.Delivery_Status__c);
    Assert.isTrue(row.Delivery_Error__c.startsWith('LINE 401'));
  }

  @IsTest
  static void sendMessageToUnlinkedCustomerSkipsLine() {
    Account acc = customer();
    acc.LINE_User_ID__c = null;
    update acc;

    LINE_Message__c saved = NoritzLineChatController.sendMessage(
      acc.Id,
      'Hello'
    );

    LINE_Message__c row = [
      SELECT Delivery_Status__c
      FROM LINE_Message__c
      WHERE Id = :saved.Id
    ];
    Assert.isNull(
      row.Delivery_Status__c,
      'No push was attempted, so no delivery status'
    );
  }

  @IsTest
  static void sendMessageRejectsBlank() {
    try {
      NoritzLineChatController.sendMessage(customer().Id, '   ');
      Assert.fail('Expected an error for a blank message');
    } catch (AuraHandledException e) {
      Assert.areEqual('Type a message before sending.', e.getMessage());
    }
    Assert.areEqual(0, [SELECT COUNT() FROM LINE_Message__c]);
  }

  @IsTest
  static void sendMessageRejectsTooLong() {
    try {
      NoritzLineChatController.sendMessage(customer().Id, 'x'.repeat(4001));
      Assert.fail('Expected an error for a message over 4000 characters');
    } catch (AuraHandledException e) {
      Assert.isTrue(e.getMessage().startsWith('Message is too long'));
    }
  }

  @IsTest
  static void triggerPublishesOneRefreshPerAccount() {
    Id accountId = customer().Id;

    Test.startTest();
    Integer before = Limits.getDmlStatements();
    insert new List<LINE_Message__c>{
      new LINE_Message__c(
        Account__c = accountId,
        Direction__c = 'Inbound',
        Message_Body__c = 'a'
      ),
      new LINE_Message__c(
        Account__c = accountId,
        Direction__c = 'Inbound',
        Message_Body__c = 'b'
      ),
      new LINE_Message__c(
        Direction__c = 'Inbound',
        Message_Body__c = 'no account'
      )
    };
    Integer used = Limits.getDmlStatements() - before;
    Test.stopTest();

    Assert.areEqual(
      2,
      used,
      'Expected the insert plus a single publish call for the batch'
    );
  }

  @IsTest
  static void leadChatShowsLeadMessagesAndSendsToLeadLineUser() {
    Lead l = new Lead(LastName = 'Friend', LINE_User_ID__c = 'U_lead_1');
    insert l;
    insert new LINE_Message__c(
      Lead__c = l.Id,
      Direction__c = 'Inbound',
      Message_Body__c = 'hello from LINE'
    );
    Test.setMock(HttpCalloutMock.class, new LineMock(200));

    NoritzLineChatController.ChatData data = NoritzLineChatController.getChat(
      l.Id
    );
    Assert.areEqual(l.Id, data.chatOwnerId);
    Assert.areEqual('U_lead_1', data.lineUserId);
    Assert.areEqual(1, data.messages.size());

    Test.startTest();
    LINE_Message__c saved = NoritzLineChatController.sendMessage(l.Id, 'Hi');
    Test.stopTest();
    LINE_Message__c row = [
      SELECT Lead__c, Account__c, LINE_User_ID__c, Delivery_Status__c
      FROM LINE_Message__c
      WHERE Id = :saved.Id
    ];
    Assert.areEqual(l.Id, row.Lead__c);
    Assert.isNull(row.Account__c);
    Assert.areEqual('U_lead_1', row.LINE_User_ID__c);
    Assert.areEqual('Sent', row.Delivery_Status__c);
  }

  @IsTest
  static void caseChatShowsAccountChatAndTagsTheCase() {
    Account acc = customer();
    Case c = new Case(AccountId = acc.Id, Subject = 'Filter');
    insert c;
    insert new LINE_Message__c(
      Account__c = acc.Id,
      Direction__c = 'Inbound',
      Message_Body__c = 'my filter'
    );
    Test.setMock(HttpCalloutMock.class, new LineMock(200));

    NoritzLineChatController.ChatData data = NoritzLineChatController.getChat(
      c.Id
    );
    Assert.areEqual(acc.Id, data.chatOwnerId);
    Assert.areEqual(1, data.messages.size());

    Test.startTest();
    LINE_Message__c saved = NoritzLineChatController.sendMessage(c.Id, 'On it');
    Test.stopTest();
    LINE_Message__c row = [
      SELECT Account__c, Case__c
      FROM LINE_Message__c
      WHERE Id = :saved.Id
    ];
    Assert.areEqual(acc.Id, row.Account__c);
    Assert.areEqual(c.Id, row.Case__c);
  }

  @IsTest
  static void caseWithoutAccountHasNoChat() {
    Case c = new Case(Subject = 'Orphan');
    insert c;

    Assert.isTrue(NoritzLineChatController.getChat(c.Id).noCustomer);
    try {
      NoritzLineChatController.sendMessage(c.Id, 'Hi');
      Assert.fail('Expected an error');
    } catch (AuraHandledException e) {
      Assert.areEqual(
        'Link this case to a customer before sending.',
        e.getMessage()
      );
    }
  }

  @IsTest
  static void templatesFillInTheCustomerName() {
    List<NoritzLineChatController.Template> templates = NoritzLineChatController.getTemplates(
      customer().Id
    );
    for (NoritzLineChatController.Template t : templates) {
      Assert.isFalse(t.body.contains('{Name}'), t.label);
    }
  }
}
