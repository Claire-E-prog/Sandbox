public without sharing class SyntheticSalesDataCleanup {
  public static CleanupResult cleanupAll() {
    return cleanupByPattern('SYNTH-%');
  }

  public static CleanupResult cleanupRun(String runKey) {
    if (String.isBlank(runKey) || !runKey.startsWith('SYNTH-')) {
      throw new SyntheticDataException(
        'A cleanup run key must start with SYNTH-.'
      );
    }
    return cleanupByPattern(runKey + '%');
  }

  private static CleanupResult cleanupByPattern(String namePattern) {
    assertSafeOrg();
    CleanupResult result = new CleanupResult();

    List<Opportunity> opportunities = [
      SELECT Id
      FROM Opportunity
      WHERE Name LIKE :namePattern
    ];
    Set<Id> opportunityIds = new Map<Id, Opportunity>(opportunities).keySet();
    List<Contact> contacts = [
      SELECT Id
      FROM Contact
      WHERE LastName LIKE :namePattern
    ];
    Set<Id> contactIds = new Map<Id, Contact>(contacts).keySet();
    List<Account> accounts = [
      SELECT Id
      FROM Account
      WHERE Name LIKE :namePattern
    ];
    Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
    List<Lead> leads = [
      SELECT Id
      FROM Lead
      WHERE LastName LIKE :namePattern
    ];
    Set<Id> leadIds = new Map<Id, Lead>(leads).keySet();

    Set<Id> activityWhoIds = new Set<Id>();
    activityWhoIds.addAll(contactIds);
    activityWhoIds.addAll(leadIds);
    Set<Id> activityWhatIds = new Set<Id>();
    activityWhatIds.addAll(accountIds);
    activityWhatIds.addAll(opportunityIds);

    List<Task> tasks = activityWhoIds.isEmpty() && activityWhatIds.isEmpty()
      ? new List<Task>()
      : [
          SELECT Id
          FROM Task
          WHERE WhoId IN :activityWhoIds OR WhatId IN :activityWhatIds
        ];
    List<Event> events = activityWhoIds.isEmpty() && activityWhatIds.isEmpty()
      ? new List<Event>()
      : [
          SELECT Id
          FROM Event
          WHERE WhoId IN :activityWhoIds OR WhatId IN :activityWhatIds
        ];
    delete tasks;
    delete events;

    List<OpportunityLineItem> lineItems = opportunityIds.isEmpty()
      ? new List<OpportunityLineItem>()
      : [
          SELECT Id
          FROM OpportunityLineItem
          WHERE OpportunityId IN :opportunityIds
        ];
    delete lineItems;
    delete opportunities;
    delete contacts;
    delete accounts;
    delete leads;

    List<Product2> products = [
      SELECT Id
      FROM Product2
      WHERE ProductCode LIKE :namePattern
    ];
    Set<Id> productIds = new Map<Id, Product2>(products).keySet();
    List<PricebookEntry> entries = productIds.isEmpty()
      ? new List<PricebookEntry>()
      : [
          SELECT Id
          FROM PricebookEntry
          WHERE Product2Id IN :productIds
        ];
    delete entries;
    delete products;

    result.taskCount = tasks.size();
    result.eventCount = events.size();
    result.lineItemCount = lineItems.size();
    result.opportunityCount = opportunities.size();
    result.contactCount = contacts.size();
    result.accountCount = accounts.size();
    result.leadCount = leads.size();
    result.pricebookEntryCount = entries.size();
    result.productCount = products.size();
    System.debug(LoggingLevel.WARN, result.summary());
    return result;
  }

  private static void assertSafeOrg() {
    if (Test.isRunningTest()) {
      return;
    }
    Organization orgInfo = [
      SELECT IsSandbox, OrganizationType
      FROM Organization
      LIMIT 1
    ];
    if (
      !orgInfo.IsSandbox && orgInfo.OrganizationType != 'Developer Edition'
    ) {
      throw new SyntheticDataException(
        'Synthetic data cleanup is allowed only in a sandbox or Developer Edition org.'
      );
    }
  }

  public class CleanupResult {
    public Integer taskCount;
    public Integer eventCount;
    public Integer lineItemCount;
    public Integer opportunityCount;
    public Integer contactCount;
    public Integer accountCount;
    public Integer leadCount;
    public Integer pricebookEntryCount;
    public Integer productCount;

    public String summary() {
      return 'Synthetic cleanup: ' +
        taskCount +
        ' tasks, ' +
        eventCount +
        ' events, ' +
        lineItemCount +
        ' line items, ' +
        opportunityCount +
        ' opportunities, ' +
        contactCount +
        ' contacts, ' +
        accountCount +
        ' accounts, ' +
        leadCount +
        ' leads, ' +
        pricebookEntryCount +
        ' price book entries, and ' +
        productCount +
        ' products.';
    }
  }
}
