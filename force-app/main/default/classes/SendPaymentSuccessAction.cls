public with sharing class SendPaymentSuccessAction {
  // Set by Reset Demo while it seeds past payments, so resetting doesn't message the customer.
  public static Boolean suppress = false;

  // Called from the Payment Success flow while the successful payment is being saved.
  // LINE can't be called inside that save, so the push runs in a queueable afterwards, as the
  // same user (who has access to the LINE named credential).
  @InvocableMethod(
    label='Send payment success message on LINE'
    description='Queues a LINE message notifying the customer of a successful payment.'
    category='LINE'
  )
  public static void send(List<Id> contractIds) {
    if (suppress) {
      return;
    }
    System.enqueueJob(new SuccessMessageJob(new Set<Id>(contractIds)));
  }

  public class SuccessMessageJob implements Queueable, Database.AllowsCallouts {
    private final Set<Id> contractIds;

    public SuccessMessageJob(Set<Id> contractIds) {
      this.contractIds = contractIds;
    }

    public void execute(QueueableContext context) {
      List<LINE_Message__c> messages = new List<LINE_Message__c>();
      for (Contracts__c c : [
        SELECT
          Id,
          Account__c,
          Account__r.FirstName,
          Account__r.LastName,
          Account__r.LINE_User_ID__c
        FROM Contracts__c
        WHERE Id IN :contractIds
      ]) {
        String body =
          LineMessagingService.addressAs(
            c.Account__r.FirstName,
            c.Account__r.LastName
          ) +
          'Thank you! We have successfully received the payment for your monthly subscription.';

        messages.add(
          LineMessagingService.outbound(
            c.Account__c,
            c.Account__r.LINE_User_ID__c,
            body,
            'Text' // Updated from 'Payment Retry'
          )
        );
      }
      LineMessagingService.pushAndInsert(messages);
    }
  }
}
