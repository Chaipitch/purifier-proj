public with sharing class SendPaymentSuccessAction {
  // Called from the Payment Success flow while the successful payment is being saved.
  // LINE can't be called inside that save, so the push runs in a queueable afterwards, as the
  // same user (who has access to the LINE named credential).
  @InvocableMethod(
    label='Send payment success message on LINE'
    description='Queues a LINE message notifying the customer of a successful payment.'
    category='LINE'
  )
  public static void send(List<Id> contractIds) {
    System.enqueueJob(new SuccessMessageJob(new Set<Id>(contractIds)));
  }

  public class SuccessMessageJob implements Queueable, Database.AllowsCallouts {
    private final Set<Id> contractIds;

    public SuccessMessageJob(Set<Id> contractIds) {
      this.contractIds = contractIds;
    }

    public void execute(QueueableContext context) {
      System.debug('--- QUEUEABLE STARTED ---');
      System.debug('Contract IDs received: ' + contractIds);
      List<LINE_Message__c> messages = new List<LINE_Message__c>();
      for (Contract c : [
        SELECT
          Id,
          AccountId,
          Account.FirstName,
          Account.LastName,
          Account.LINE_User_ID__c
        FROM Contract
        WHERE Id IN :contractIds
      ]) {
        String body =
          LineMessagingService.addressAs(
            c.Account.FirstName,
            c.Account.LastName
          ) +
          'Thank you! We have successfully received the payment for your monthly subscription.';

        messages.add(
          LineMessagingService.outbound(
            c.AccountId,
            c.Account.LINE_User_ID__c,
            body,
            'Text' // Updated from 'Payment Retry'
          )
        );
      }
      System.debug('messages send success:' + messages);
      LineMessagingService.pushAndInsert(messages);
    }
  }
}
