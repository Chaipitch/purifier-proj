public with sharing class SimulatePaymentSuccessAction {
  // On a Contract: records a successful payment, and the Payment Success flow reacts exactly as it
  // would to a real success payload from the payment provider.
  // On a Lead: the first payment converts the lead (see LeadConversionService); returns the new
  // Account id so the page can open it. Returns null for a Contract.
  @AuraEnabled
  public static Id simulate(Id recordId) {
    if (recordId.getSObjectType() == Lead.SObjectType) {
      try {
        return LeadConversionService.convertOnFirstPayment(recordId);
      } catch (LeadConversionService.ConversionException e) {
        AuraHandledException error = new AuraHandledException(e.getMessage());
        error.setMessage(e.getMessage());
        throw error;
      }
    }
    Contract c = [
      SELECT AccountId, Subscription_Plan__c
      FROM Contract
      WHERE Id = :recordId
    ];
    insert new Payment_History__c(
      Contract__c = c.Id,
      Account__c = c.AccountId,
      Amount__c = SubscriptionPlans.priceOf(c.Subscription_Plan__c),
      Status__c = 'Success'
    );
    return null;
  }
}
