// Turns a LINE lead into a customer on its first successful payment: Person Account, contract,
// payment, and the lead's chat and assets moved over. Called by the "Simulate Payment Success"
// button today; a real payment webhook can call convertOnFirstPayment the same way.
public with sharing class LeadConversionService {
  @TestVisible
  private static final String CONVERTED_STATUS = 'Closed - Converted';

  public class ConversionException extends Exception {
  }

  // Returns the new Account id.
  public static Id convertOnFirstPayment(Id leadId) {
    Lead l = [
      SELECT
        Id,
        IsConverted,
        LINE_User_ID__c,
        Subscription_Plan__c,
        Stripe_Sub_ID__c
      FROM Lead
      WHERE Id = :leadId
    ];
    if (l.IsConverted) {
      throw new ConversionException('This lead has already been converted.');
    }
    if (String.isBlank(l.Subscription_Plan__c)) {
      throw new ConversionException(
        'Choose a Subscription Plan on the lead before taking the first payment.'
      );
    }

    // Company is blank on LINE leads, so this creates a Person Account (Account and Contact in one).
    Database.LeadConvert convert = new Database.LeadConvert();
    convert.setLeadId(l.Id);
    convert.setConvertedStatus(CONVERTED_STATUS);
    convert.setDoNotCreateOpportunity(true);
    Database.LeadConvertResult result = Database.convertLead(convert);
    Id accountId = result.getAccountId();

    update new Account(
      Id = accountId,
      LINE_User_ID__c = l.LINE_User_ID__c,
      Customer_Status__c = 'Active',
      Converted_From_LINE_Lead__c = true
    );

    // Reuses the contract of an earlier failed attempt, if there was one.
    Contracts__c contract = contractFor(l);
    contract.Account__c = accountId;
    upsert contract;

    relinkToAccount(l.Id, accountId);

    // The Payment Success flow activates the contract and thanks the customer on LINE.
    insert new Payment_History__c(
      Subscription_Contract__c = contract.Id,
      Account__c = accountId,
      Lead__c = l.Id,
      Amount__c = SubscriptionPlans.priceOf(l.Subscription_Plan__c),
      Status__c = 'Success'
    );
    return accountId;
  }

  // The lead's contract before conversion: the Pending Payment contract of an earlier failed
  // attempt, or a new one (not saved). l needs Id, Subscription_Plan__c and Stripe_Sub_ID__c.
  public static Contracts__c contractFor(Lead l) {
    List<Contracts__c> existing = [
      SELECT Id, Account__c, Lead__c, Subscription_Plan__c
      FROM Contracts__c
      WHERE Lead__c = :l.Id AND Account__c = NULL
      ORDER BY CreatedDate
      LIMIT 1
    ];
    Contracts__c c = existing.isEmpty()
      ? new Contracts__c(Lead__c = l.Id, Status__c = 'Pending Payment')
      : existing[0];
    Date today = Date.today();
    c.Contract_Start_Date__c = today;
    c.Contract_Term_months__c = 12;
    c.Contract_End_Date__c = GregorianDates.addMonths(today, 12);
    c.Subscription_Plan__c = l.Subscription_Plan__c;
    c.Stripe_Sub_ID__c = l.Stripe_Sub_ID__c;
    c.Next_Billing_Date__c = GregorianDates.startOfMonth(
      GregorianDates.addMonths(today, 1)
    );
    return c;
  }

  // The lead's LINE conversation and any assets recorded against it now belong to the customer.
  private static void relinkToAccount(Id leadId, Id accountId) {
    List<LINE_Message__c> messages = [
      SELECT Id
      FROM LINE_Message__c
      WHERE Lead__c = :leadId
    ];
    for (LINE_Message__c m : messages) {
      m.Account__c = accountId;
    }
    update messages;

    // Earlier failed attempts: their contract now belongs to the customer too.
    List<Payment_History__c> payments = [
      SELECT Id
      FROM Payment_History__c
      WHERE Lead__c = :leadId AND Account__c = NULL
    ];
    for (Payment_History__c p : payments) {
      p.Account__c = accountId;
    }
    update payments;

    List<Assets__c> assets = [
      SELECT Id
      FROM Assets__c
      WHERE Lead__c = :leadId
    ];
    for (Assets__c a : assets) {
      a.Account__c = accountId;
    }
    update assets;
  }
}
