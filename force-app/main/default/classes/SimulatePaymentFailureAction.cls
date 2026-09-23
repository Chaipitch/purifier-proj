public with sharing class SimulatePaymentFailureAction {
  @TestVisible
  private static final String FAILURE_REASON = 'Card Expired (ERR-02)';
  private static final Map<String, Decimal> PLAN_PRICES = new Map<String, Decimal>{
    'Standard (900 THB)' => 900,
    'Premium (1,500 THB)' => 1500
  };

  // Inserting the failed payment is all this does: the Payment Failure Recovery flow reacts
  // to it exactly as it would to a real failure from the payment provider.
  @AuraEnabled
  public static void simulate(Id contractId) {
    Contract c = [
      SELECT AccountId, Subscription_Plan__c
      FROM Contract
      WHERE Id = :contractId
    ];
    insert new Payment_History__c(
      Contract__c = c.Id,
      Account__c = c.AccountId,
      Amount__c = PLAN_PRICES.get(c.Subscription_Plan__c),
      Status__c = 'Failed',
      Failure_Reason__c = FAILURE_REASON
    );
  }
}
