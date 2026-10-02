public with sharing class SimulatePaymentFailureAction {
  @TestVisible
  private static final String FAILURE_REASON = 'Card Expired (ERR-02)';

  // Inserting the failed payment is all this does: the Payment Failure Recovery flow reacts
  // to it exactly as it would to a real failure from the payment provider.
  @AuraEnabled
  public static void simulate(Id contractId) {
    Contracts__c c = [
      SELECT Account__c, Subscription_Plan__c
      FROM Contracts__c
      WHERE Id = :contractId
    ];
    insert new Payment_History__c(
      Contract__c = c.Id,
      Account__c = c.Account__c,
      Amount__c = SubscriptionPlans.priceOf(c.Subscription_Plan__c),
      Status__c = 'Failed',
      Failure_Reason__c = FAILURE_REASON
    );
  }
}
