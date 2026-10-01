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

  // recordId: a Contract (existing customer) or a Lead (new LINE customer before payment).
  @AuraEnabled
  public static Result send(Id recordId) {
    Result result = new Result();
    Checkout checkout = recordId.getSObjectType() == Lead.SObjectType
      ? forLead(recordId)
      : forContract(recordId);
    if (checkout.error != null) {
      result.status = 'Error';
      result.message = checkout.error;
      return result;
    }

    String url = CHECKOUT_BASE_URL + checkout.subscriptionId;
    String plan = String.isBlank(checkout.plan) ? '' : ' ' + checkout.plan;
    String body =
      LineMessagingService.addressAs(checkout.firstName, checkout.lastName) +
      'Thank you for choosing NORITZ. Please complete payment for your' +
      plan +
      ' package using the link below to start your service.\n' +
      url;

    LINE_Message__c saved = LineMessagingService.sendAndSave(
      checkout.chatRecordId,
      body,
      'Checkout Link'
    );
    // After the push: Apex allows DML after a callout, not before.
    if (checkout.leadToUpdate != null) {
      update checkout.leadToUpdate;
    }
    if (saved.Delivery_Status__c == 'Sent') {
      result.status = 'Sent';
      result.message = 'The customer has it on LINE.';
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

  private class Checkout {
    Id chatRecordId;
    String firstName;
    String lastName;
    String plan;
    String subscriptionId;
    Lead leadToUpdate;
    String error;
  }

  private static Checkout forContract(Id contractId) {
    Contract c = [
      SELECT
        AccountId,
        Account.FirstName,
        Account.LastName,
        Stripe_Sub_ID__c,
        Subscription_Plan__c
      FROM Contract
      WHERE Id = :contractId
    ];
    Checkout checkout = new Checkout();
    checkout.chatRecordId = c.AccountId;
    checkout.firstName = c.Account.FirstName;
    checkout.lastName = c.Account.LastName;
    checkout.plan = c.Subscription_Plan__c;
    checkout.subscriptionId = c.Stripe_Sub_ID__c;
    if (String.isBlank(c.Stripe_Sub_ID__c)) {
      checkout.error = 'This contract has no Stripe subscription id, so there is no checkout link to send.';
    }
    return checkout;
  }

  // A lead gets a mock subscription id the first time, and moves to Working - Contacted.
  private static Checkout forLead(Id leadId) {
    Lead l = [
      SELECT
        Id,
        FirstName,
        LastName,
        IsConverted,
        Subscription_Plan__c,
        Stripe_Sub_ID__c
      FROM Lead
      WHERE Id = :leadId
    ];
    Checkout checkout = new Checkout();
    checkout.chatRecordId = l.Id;
    checkout.firstName = l.FirstName;
    checkout.lastName = l.LastName;
    checkout.plan = l.Subscription_Plan__c;
    if (l.IsConverted) {
      checkout.error = 'This lead is already a customer. Send the link from their contract.';
      return checkout;
    }
    if (String.isBlank(l.Subscription_Plan__c)) {
      checkout.error = 'Choose a Subscription Plan on the lead first.';
      return checkout;
    }
    checkout.subscriptionId = String.isBlank(l.Stripe_Sub_ID__c)
      ? 'sub_demo_' + String.valueOf(l.Id).right(6).toLowerCase()
      : l.Stripe_Sub_ID__c;
    checkout.leadToUpdate = new Lead(
      Id = l.Id,
      Stripe_Sub_ID__c = checkout.subscriptionId,
      Status = 'Working - Contacted'
    );
    return checkout;
  }
}
