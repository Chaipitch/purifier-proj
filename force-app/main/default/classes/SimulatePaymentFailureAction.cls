public with sharing class SimulatePaymentFailureAction {
  @TestVisible
  private static final String FAILURE_REASON = 'Card Expired (ERR-02)';

  // Inserting the failed payment is all this does: the Payment Failure Recovery flow reacts
  // to it exactly as it would to a real failure from the payment provider.
  // recordId: a contract (existing customer) or a Lead (its first payment, after the checkout link).
  @AuraEnabled
  public static void simulate(Id recordId) {
    Contracts__c c = recordId.getSObjectType() == Lead.SObjectType
      ? leadContract(recordId)
      : [
          SELECT Id, Account__c, Lead__c, Subscription_Plan__c
          FROM Contracts__c
          WHERE Id = :recordId
        ];
    insert new Payment_History__c(
      Subscription_Contract__c = c.Id,
      Account__c = c.Account__c,
      Lead__c = c.Lead__c,
      Amount__c = SubscriptionPlans.priceOf(c.Subscription_Plan__c),
      Status__c = 'Failed',
      Failure_Reason__c = FAILURE_REASON
    );
  }

  // A payment always belongs to a contract, so a lead's first attempt gets a Pending Payment
  // contract linked to the lead. The conversion on a later successful payment reuses it.
  private static Contracts__c leadContract(Id leadId) {
    Lead l = [
      SELECT Id, IsConverted, Subscription_Plan__c, Stripe_Sub_ID__c
      FROM Lead
      WHERE Id = :leadId
    ];
    if (l.IsConverted) {
      throw error(
        'This lead is already a customer. Simulate the failure from their contract.'
      );
    }
    if (String.isBlank(l.Subscription_Plan__c)) {
      throw error('Choose a Subscription Plan on the lead first.');
    }
    if (String.isBlank(l.Stripe_Sub_ID__c)) {
      throw error(
        'Send the Stripe checkout link first: a payment can only fail after checkout.'
      );
    }
    Contracts__c c = LeadConversionService.contractFor(l);
    upsert c;
    return c;
  }

  // setMessage so tests and the toast see the text, not "Script-thrown exception".
  private static AuraHandledException error(String message) {
    AuraHandledException e = new AuraHandledException(message);
    e.setMessage(message);
    return e;
  }
}
