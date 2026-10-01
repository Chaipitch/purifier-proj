// Maintenance: reminds customers on LINE that their purifier filter is due for replacement.
// Flows call send() (the daily Filter Reminder flow); the "Send Filter Reminder" button on an
// Asset calls sendNow() for one asset.
public with sharing class SendFilterReminderAction {
  private static final List<String> MONTHS = new List<String>{
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  };

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
    List<Asset> reminded = new List<Asset>();
    for (Asset a : [
      SELECT
        Id,
        Name,
        SerialNumber,
        Next_Filter_Replacement__c,
        AccountId,
        Account.FirstName,
        Account.LastName,
        Account.LINE_User_ID__c
      FROM Asset
      WHERE
        Id IN :assetIds
        AND AccountId != NULL
        AND Next_Filter_Replacement__c != NULL
    ]) {
      messages.add(
        LineMessagingService.outbound(
          a.AccountId,
          a.Account.LINE_User_ID__c,
          reminderText(a),
          'Filter Reminder'
        )
      );
      reminded.add(
        new Asset(Id = a.Id, Last_Filter_Reminder__c = Date.today())
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
  private static String reminderText(Asset a) {
    String product = String.isBlank(a.SerialNumber)
      ? a.Name
      : a.Name + ' (' + a.SerialNumber + ')';
    return LineMessagingService.addressAs(
        a.Account.FirstName,
        a.Account.LastName
      ) +
      'The filter on your ' +
      product +
      ' is due for replacement on ' +
      formatDate(a.Next_Filter_Replacement__c) +
      '. Reply here to book a technician visit.';
  }

  // "7 Oct 2026" whatever the user's locale. Not d.year(): for a th_TH user it returns the
  // Buddhist year (2569). String.valueOf gives ISO yyyy-MM-dd in the Gregorian calendar.
  private static String formatDate(Date d) {
    List<String> parts = String.valueOf(d).split('-');
    return Integer.valueOf(parts[2]) +
      ' ' +
      MONTHS[Integer.valueOf(parts[1]) - 1] +
      ' ' +
      parts[0];
  }
}
