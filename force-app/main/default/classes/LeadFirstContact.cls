// The first LINE message sent to a lead (typed in the chat, picked from Templates, or the checkout
// link) moves it from Open - Not Contacted to Working - Contacted. A lead already past Open - Not
// Contacted is left alone, and messages from the customer don't count. Called by LineMessageTrigger.
public with sharing class LeadFirstContact {
  @TestVisible
  private static final String NOT_CONTACTED = 'Open - Not Contacted';
  @TestVisible
  private static final String CONTACTED = 'Working - Contacted';

  public static void markContacted(List<LINE_Message__c> messages) {
    Set<Id> leadIds = new Set<Id>();
    for (LINE_Message__c m : messages) {
      // Account__c set means the lead has become a customer and the chat is the Account's.
      if (
        m.Direction__c == 'Outbound' &&
        m.Lead__c != null &&
        m.Account__c == null
      ) {
        leadIds.add(m.Lead__c);
      }
    }
    if (leadIds.isEmpty()) {
      return;
    }
    List<Lead> leads = [
      SELECT Id
      FROM Lead
      WHERE Id IN :leadIds AND Status = :NOT_CONTACTED AND IsConverted = FALSE
    ];
    for (Lead l : leads) {
      l.Status = CONTACTED;
    }
    update leads;
  }
}
