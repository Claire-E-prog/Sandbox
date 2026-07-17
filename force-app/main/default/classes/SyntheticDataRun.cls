public class SyntheticDataRun {
  public String runKey;
  public List<Id> ownerIds = new List<Id>();
  public Id standardPricebookId;

  public List<Account> accounts = new List<Account>();
  public List<Contact> contacts = new List<Contact>();
  public List<Lead> leads = new List<Lead>();
  public List<Product2> products = new List<Product2>();
  public List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
  public List<Opportunity> opportunities = new List<Opportunity>();
  public List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();
  public List<Task> tasks = new List<Task>();
  public List<Event> events = new List<Event>();

  public SyntheticDataRun(String runKey, List<Id> ownerIds) {
    this.runKey = runKey;
    this.ownerIds = ownerIds;
  }

  public String marker() {
    return 'Synthetic sales data; run=' + runKey;
  }
}
