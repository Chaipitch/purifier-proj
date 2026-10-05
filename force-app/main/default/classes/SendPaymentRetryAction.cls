public with sharing class SendPaymentRetryAction {
  // Mock only: "/demo/" in the path so nobody mistakes it for a live Stripe link.
  @TestVisible
  private static final String RETRY_BASE_URL = 'https://checkout.stripe.com/demo/';

  // Called from the Payment Failure Recovery flow while the failed payment is being saved.
  // LINE can't be called inside that save, so the push runs in a queueable afterwards, as the
  // same user (who has access to the LINE named credential).
  @InvocableMethod(
    label='Send payment retry link on LINE'
    description='Queues a LINE message asking the customer to update their payment method.'
    category='LINE'
  )
  public static void send(List<Id> contractIds) {
    System.enqueueJob(new RetryMessageJob(new Set<Id>(contractIds)));
  }

  public class RetryMessageJob implements Queueable, Database.AllowsCallouts {
    private final Set<Id> contractIds;

    public RetryMessageJob(Set<Id> contractIds) {
      this.contractIds = contractIds;
    }

    public void execute(QueueableContext context) {
      List<LINE_Message__c> messages = new List<LINE_Message__c>();
      for (Contracts__c c : [
        SELECT Id, Account__c, Lead__c, Stripe_Sub_ID__c
        FROM Contracts__c
        WHERE Id IN :contractIds
      ]) {
        // A lead's first payment has no customer yet: the retry link goes to the lead's chat.
        Id customerId = c.Account__c != null ? c.Account__c : c.Lead__c;
        if (customerId == null) {
          continue;
        }
        LineMessagingService.Recipient to = LineMessagingService.recipientFor(
          customerId
        );
        String reference = String.isBlank(c.Stripe_Sub_ID__c)
          ? (String) c.Id
          : c.Stripe_Sub_ID__c;
        String body =
          LineMessagingService.addressAs(to.firstName, to.lastName) +
          'Payment failed for your monthly subscription. Please update your payment method using this link:\n' +
          RETRY_BASE_URL +
          reference +
          '/update-payment';
        messages.add(LineMessagingService.outbound(to, body, 'Payment Retry'));
      }
      LineMessagingService.pushAndInsert(messages);
    }
  }
}
