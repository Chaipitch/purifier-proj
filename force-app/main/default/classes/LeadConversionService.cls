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

    Date today = Date.today();
    Contract contract = new Contract(
      AccountId = accountId,
      Status = 'Pending Payment',
      StartDate = today,
      ContractTerm = 12,
      Subscription_Plan__c = l.Subscription_Plan__c,
      Stripe_Sub_ID__c = l.Stripe_Sub_ID__c,
      // Not toStartOfMonth(): for a th_TH user it saves the Buddhist year.
      Next_Billing_Date__c = today.addMonths(1).addDays(1 - today.day())
    );
    insert contract;

    relinkToAccount(l.Id, accountId);

    // The Payment Success flow activates the contract and thanks the customer on LINE.
    insert new Payment_History__c(
      Contract__c = contract.Id,
      Account__c = accountId,
      Lead__c = l.Id,
      Amount__c = SubscriptionPlans.priceOf(l.Subscription_Plan__c),
      Status__c = 'Success'
    );
    return accountId;
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

    List<Asset> assets = [SELECT Id FROM Asset WHERE Lead__c = :leadId];
    for (Asset a : assets) {
      a.AccountId = accountId;
    }
    update assets;
  }
}
