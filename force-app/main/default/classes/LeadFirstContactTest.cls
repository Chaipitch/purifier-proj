@IsTest
private class LeadFirstContactTest {
  @TestSetup
  static void setup() {
    insert new Lead(
      LastName = 'First Contact',
      LINE_User_ID__c = 'U_first_contact',
      LeadSource = 'LINE',
      Status = LeadFirstContact.NOT_CONTACTED
    );
  }

  static Lead lead() {
    return [SELECT Id, Status FROM Lead WHERE LastName = 'First Contact'];
  }

  @IsTest
  static void agentMessageMarksTheLeadContacted() {
    Test.setMock(HttpCalloutMock.class, new LineCalloutMock());

    Test.startTest();
    NoritzLineChatController.sendMessage(
      lead().Id,
      'Hi, thanks for adding us!'
    );
    Test.stopTest();

    Assert.areEqual(LeadFirstContact.CONTACTED, lead().Status);
  }

  @IsTest
  static void customerMessageLeavesTheLeadOpen() {
    insert new LINE_Message__c(
      Lead__c = lead().Id,
      Direction__c = 'Inbound',
      Message_Type__c = 'Text',
      Message_Body__c = 'Hello'
    );

    Assert.areEqual(LeadFirstContact.NOT_CONTACTED, lead().Status);
  }

  // Reset Demo and the conversion move chats to the Account; those messages aren't first contact.
  @IsTest
  static void messageOnTheCustomerChatIsIgnored() {
    Id personType = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('PersonAccount')
      .getRecordTypeId();
    Account customer = new Account(
      RecordTypeId = personType,
      LastName = 'Customer'
    );
    insert customer;

    insert new LINE_Message__c(
      Lead__c = lead().Id,
      Account__c = customer.Id,
      Direction__c = 'Outbound',
      Message_Type__c = 'Text',
      Message_Body__c = 'Payment received'
    );

    Assert.areEqual(LeadFirstContact.NOT_CONTACTED, lead().Status);
  }

  @IsTest
  static void leadThatHasMovedOnIsLeftAlone() {
    // Any other open status this org has, e.g. Closed - Not Converted.
    Set<String> skip = new Set<String>{
      LeadFirstContact.NOT_CONTACTED,
      LeadFirstContact.CONTACTED
    };
    List<LeadStatus> others = [
      SELECT ApiName
      FROM LeadStatus
      WHERE IsConverted = FALSE AND ApiName NOT IN :skip
      LIMIT 1
    ];
    if (others.isEmpty()) {
      return;
    }
    String later = others[0].ApiName;
    Lead l = lead();
    l.Status = later;
    update l;

    insert new LINE_Message__c(
      Lead__c = l.Id,
      Direction__c = 'Outbound',
      Message_Type__c = 'Text',
      Message_Body__c = 'Checking in'
    );

    Assert.areEqual(later, lead().Status);
  }
}
