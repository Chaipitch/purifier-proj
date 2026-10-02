// Maintenance: reminds customers on LINE that their purifier filter is due for replacement.
// Flows call send() (the daily Filter Reminder flow); the "Send Filter Reminder" button on an
// asset (Assets__c) calls sendNow() for one asset.
public with sharing class SendFilterReminderAction {
  public class Result {
    @AuraEnabled
    public String status; // Sent, Failed, Not linked or Error
    @AuraEnabled
    public String message;
  }

  // Flows run inside a record save, where LINE can't be called, so the push runs in a queueable.
  @InvocableMethod(
    label='Send filter replacement reminder on LINE'
    description='Messages each asset\'s customer on LINE that the filter is due, and records when.'
    category='LINE'
  )
  public static void send(List<Id> assetIds) {
    if (assetIds != null && !assetIds.isEmpty()) {
      System.enqueueJob(new ReminderJob(new Set<Id>(assetIds)));
    }
  }

  @AuraEnabled
  public static Result sendNow(Id assetId) {
    Result result = new Result();
    List<LINE_Message__c> sent = remind(new Set<Id>{ assetId });
    if (sent.isEmpty()) {
      result.status = 'Error';
      result.message = 'This asset needs a customer and a Next Filter Date before a reminder can be sent.';
    } else if (sent[0].Delivery_Status__c == 'Sent') {
      result.status = 'Sent';
      result.message = 'The customer has the reminder on LINE.';
    } else if (sent[0].Delivery_Status__c == 'Failed') {
      result.status = 'Failed';
      result.message =
        'Saved in the chat, but LINE rejected it: ' + sent[0].Delivery_Error__c;
    } else {
      result.status = 'Not linked';
      result.message = 'The customer has no LINE account linked. The reminder was saved in the chat only.';
    }
    return result;
  }

  public class ReminderJob implements Queueable, Database.AllowsCallouts {
    private final Set<Id> assetIds;

    public ReminderJob(Set<Id> assetIds) {
      this.assetIds = assetIds;
    }

    public void execute(QueueableContext context) {
      remind(assetIds);
    }
  }

  // Pushes first, then saves the messages and stamps Last_Filter_Reminder__c: no callout may
  // follow DML in the same transaction.
  private static List<LINE_Message__c> remind(Set<Id> assetIds) {
    List<LINE_Message__c> messages = new List<LINE_Message__c>();
    List<Assets__c> reminded = new List<Assets__c>();
    for (Assets__c a : [
      SELECT
        Id,
        Name,
        Serial_Number__c,
        Next_Filter_Replacement__c,
        Account__c,
        Account__r.FirstName,
        Account__r.LastName,
        Account__r.LINE_User_ID__c
      FROM Assets__c
      WHERE
        Id IN :assetIds
        AND Account__c != NULL
        AND Next_Filter_Replacement__c != NULL
    ]) {
      messages.add(
        LineMessagingService.outbound(
          a.Account__c,
          a.Account__r.LINE_User_ID__c,
          reminderText(a),
          'Filter Reminder'
        )
      );
      reminded.add(
        new Assets__c(Id = a.Id, Last_Filter_Reminder__c = Date.today())
      );
    }
    if (messages.isEmpty()) {
      return messages;
    }
    LineMessagingService.pushAndInsert(messages);
    update reminded;
    return messages;
  }

  @TestVisible
  private static String reminderText(Assets__c a) {
    String product = String.isBlank(a.Serial_Number__c)
      ? a.Name
      : a.Name + ' (' + a.Serial_Number__c + ')';
    return LineMessagingService.addressAs(
        a.Account__r.FirstName,
        a.Account__r.LastName
      ) +
      'The filter on your ' +
      product +
      ' is due for replacement on ' +
      GregorianDates.format(a.Next_Filter_Replacement__c) +
      '. Reply here to book a technician visit.';
  }
}
