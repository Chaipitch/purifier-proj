// Monthly price of each subscription plan, keyed by the Subscription_Plan__c picklist value.
public with sharing class SubscriptionPlans {
  private static final Map<String, Decimal> PRICES = new Map<String, Decimal>{
    'Standard (900 THB)' => 900,
    'Premium (1,500 THB)' => 1500
  };

  // Null for a blank or unknown plan.
  public static Decimal priceOf(String plan) {
    return plan == null ? null : PRICES.get(plan);
  }
}
