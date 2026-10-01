public with sharing class SendCheckoutLinkAction {
  // Mock only: "/demo/" in the path so nobody mistakes it for a live Stripe link.
  @TestVisible
  private static final String CHECKOUT_BASE_URL = 'https://checkout.stripe.com/demo/';

  public class Result {
    @AuraEnabled
    public String status; // Sent, Failed, Not linked or Error
    @AuraEnabled
    public String message;
  }

  @AuraEnabled
  public static Result send(Id contractId) {
    Result result = new Result();
    Contract c = [
      SELECT
        AccountId,
        Status,
        Account.FirstName,
        Account.LastName,
        Stripe_Sub_ID__c,
        Subscription_Plan__c
      FROM Contract
      WHERE Id = :contractId
    ];
    if (String.isBlank(c.Stripe_Sub_ID__c)) {
      result.status = 'Error';
      result.message = 'This contract has no Stripe subscription id, so there is no checkout link to send.';
      return result;
    }

    String url = CHECKOUT_BASE_URL + c.Stripe_Sub_ID__c;
    String plan = String.isBlank(c.Subscription_Plan__c)
      ? ''
      : ' ' + c.Subscription_Plan__c;
    String body =
      LineMessagingService.addressAs(c.Account.FirstName, c.Account.LastName) +
      'Thank you for choosing NORITZ. Please complete payment for your' +
      plan +
      ' package using the link below to start your service.\n' +
      url;

    LINE_Message__c saved = LineMessagingService.sendAndSave(
      c.AccountId,
      body,
      'Checkout Link'
    );
    if (saved.Delivery_Status__c == 'Sent') {
      result.status = 'Sent';
      result.message = 'The customer has it on LINE.';

      // update new Contract(Id = contractId, Status = 'Pending Payment');
    } else if (saved.Delivery_Status__c == 'Failed') {
      result.status = 'Failed';
      result.message =
        'Saved in the chat, but LINE rejected it: ' + saved.Delivery_Error__c;
    } else {
      result.status = 'Not linked';
      result.message = 'The customer has no LINE account linked. The link was saved in the chat only.';
    }
    return result;
  }
}
