public with sharing class SimulatePaymentSuccessAction {
  private static final Map<String, Decimal> PLAN_PRICES = new Map<String, Decimal>{
    'Standard (900 THB)' => 900,
    'Premium (1,500 THB)' => 1500
  };

  // Inserting the successful payment is all this does: relevant flows/triggers can react
  // to it exactly as they would to a real success payload from the payment provider.
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
      Status__c = 'Success' // Make sure 'Success' matches the exact API name of your picklist value
    );
  }
}
