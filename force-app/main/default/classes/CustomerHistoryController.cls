// Backs the Customer History card: a customer's products, contracts and payments in one place.
// Works on Account pages, Case pages (the case's account) and Lead pages (records linked to the
// lead, or the account it converted to).
public with sharing class CustomerHistoryController {
  private static final Integer MAX_PAYMENTS = 20;

  public class History {
    // The Account or Lead the history belongs to; the card refreshes on events for this id.
    @AuraEnabled
    public Id customerId;
    @AuraEnabled
    public List<Assets__c> products = new List<Assets__c>();
    @AuraEnabled
    public List<Contracts__c> contracts = new List<Contracts__c>();
    @AuraEnabled
    public List<Payment_History__c> payments = new List<Payment_History__c>();
  }

  // Not cacheable: re-fetched after refresh events.
  @AuraEnabled
  public static History getHistory(Id recordId) {
    LineMessagingService.Recipient customer = LineMessagingService.recipientFor(
      recordId
    );
    History history = new History();
    Id accountId = customer.accountId;
    Id leadId = customer.leadId;
    history.customerId = accountId != null ? accountId : leadId;
    if (history.customerId == null) {
      return history;
    }

    history.products = [
      SELECT
        Id,
        Name,
        Product__r.Name,
        Serial_Number__c,
        Next_Filter_Replacement__c,
        Filter_Status_Icon__c
      FROM Assets__c
      WHERE
        (Account__c != NULL
        AND Account__c = :accountId)
        OR (Lead__c != NULL
        AND Lead__c = :leadId)
      ORDER BY CreatedDate DESC
    ];
    if (accountId != null) {
      history.contracts = [
        SELECT
          Id,
          Name,
          Subscription_Plan__c,
          Status__c,
          Contract_Start_Date__c,
          Next_Billing_Date__c
        FROM Contracts__c
        WHERE Account__c = :accountId
        ORDER BY Contract_Start_Date__c DESC NULLS LAST, CreatedDate DESC
      ];
    }
    history.payments = [
      SELECT
        Id,
        Name,
        CreatedDate,
        Amount__c,
        Status__c,
        Failure_Reason__c,
        Subscription_Contract__r.Name
      FROM Payment_History__c
      WHERE
        (Subscription_Contract__r.Account__c != NULL
        AND Subscription_Contract__r.Account__c = :accountId)
        OR (Lead__c != NULL
        AND Lead__c = :leadId)
      ORDER BY CreatedDate DESC, Name DESC
      LIMIT :MAX_PAYMENTS
    ];
    return history;
  }
}
