// Backs the LINE chat widget on Lead, Account and Case pages. A Lead shows its own chat until it
// converts; an Account shows its chat; a Case shows its Account's chat.
public with sharing class NoritzLineChatController {
  private static final Integer MAX_MESSAGES = 50;
  private static final Integer MAX_BODY_LENGTH = 4000;

  public class ChatData {
    @AuraEnabled
    public String customerName;
    @AuraEnabled
    public String lineUserId;
    // The Account or Lead whose chat this is; the widget refreshes on events for this id.
    @AuraEnabled
    public Id chatOwnerId;
    // Set on a Case page whose Case has no Account: there is no chat to show.
    @AuraEnabled
    public Boolean noCustomer = false;
    @AuraEnabled
    public List<LINE_Message__c> messages;
  }

  public class Template {
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String body;
  }

  // Not cacheable: the widget re-fetches after every refresh event and must not get a stale cached result.
  @AuraEnabled
  public static ChatData getChat(Id recordId) {
    LineMessagingService.Recipient to = LineMessagingService.recipientFor(
      recordId
    );
    ChatData data = new ChatData();
    data.customerName = to.name;
    data.lineUserId = to.lineUserId;
    data.chatOwnerId = to.accountId != null ? to.accountId : to.leadId;
    data.messages = new List<LINE_Message__c>();
    if (data.chatOwnerId == null) {
      data.noCustomer = true;
      return data;
    }

    List<LINE_Message__c> newestFirst = [
      SELECT
        Id,
        Direction__c,
        Message_Body__c,
        Message_Type__c,
        Sent_At__c,
        Delivery_Status__c,
        Delivery_Error__c
      FROM LINE_Message__c
      WHERE
        (Account__c != NULL
        AND Account__c = :to.accountId)
        OR (Lead__c != NULL
        AND Lead__c = :to.leadId
        AND Account__c = NULL)
      ORDER BY Sent_At__c DESC, Name DESC
      LIMIT :MAX_MESSAGES
    ];
    for (Integer i = newestFirst.size() - 1; i >= 0; i--) {
      data.messages.add(newestFirst[i]);
    }
    return data;
  }

  @AuraEnabled
  public static LINE_Message__c sendMessage(Id recordId, String body) {
    String text = body == null ? '' : body.trim();
    if (String.isBlank(text)) {
      throw auraError('Type a message before sending.');
    }
    if (text.length() > MAX_BODY_LENGTH) {
      throw auraError(
        'Message is too long (maximum ' + MAX_BODY_LENGTH + ' characters).'
      );
    }
    LineMessagingService.Recipient to = LineMessagingService.recipientFor(
      recordId
    );
    if (to.accountId == null && to.leadId == null) {
      throw auraError('Link this case to a customer before sending.');
    }

    LINE_Message__c msg = LineMessagingService.outbound(to, text, 'Text');
    LineMessagingService.pushAndInsert(new List<LINE_Message__c>{ msg });
    return msg;
  }

  // Templates for the menu above the message box, with {Name} already filled in.
  @AuraEnabled(cacheable=true)
  public static List<Template> getTemplates(Id recordId) {
    LineMessagingService.Recipient to = LineMessagingService.recipientFor(
      recordId
    );
    String pageType = recordId.getSObjectType().getDescribe().getName();
    String name = String.isNotBlank(to.firstName) ? to.firstName : to.lastName;
    if (
      String.isBlank(name) ||
      name.startsWith(LineMessagingService.PLACEHOLDER_PREFIX)
    ) {
      name = 'there';
    }

    List<Template> templates = new List<Template>();
    for (LINE_Chat_Template__mdt t : [
      SELECT MasterLabel, Body__c, Applies_To__c
      FROM LINE_Chat_Template__mdt
      ORDER BY Sort_Order__c NULLS LAST, MasterLabel
    ]) {
      if (
        String.isBlank(t.Body__c) ||
        (String.isNotBlank(t.Applies_To__c) &&
        t.Applies_To__c != 'All' &&
        t.Applies_To__c != pageType)
      ) {
        continue;
      }
      Template item = new Template();
      item.label = t.MasterLabel;
      item.body = t.Body__c.replace('{Name}', name);
      templates.add(item);
    }
    return templates;
  }

  private static AuraHandledException auraError(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
