public without sharing class SyntheticSalesDataCleanup {
  public static CleanupResult cleanupAll() {
    return cleanupByPattern('SYNTH-%', null);
  }

  public static CleanupResult cleanupRun(String runKey) {
    if (
      String.isBlank(runKey) ||
      runKey.length() > 40 ||
      !Pattern.matches('^SYNTH-[A-Za-z0-9-]+$', runKey)
    ) {
      throw new SyntheticDataException(
        'A cleanup run key must match SYNTH-[A-Za-z0-9-]+.'
      );
    }
    return cleanupByPattern(runKey + '-%', runKey);
  }

  private static CleanupResult cleanupByPattern(
    String namePattern,
    String exactRunKey
  ) {
    assertSafeOrg();
    CleanupResult result = new CleanupResult();

    List<Opportunity> opportunities = new List<Opportunity>();
    for (Opportunity candidate : [
      SELECT Id, Description
      FROM Opportunity
      WHERE Name LIKE :namePattern
      LIMIT 9001
    ]) {
      if (matchesRun(candidate.Description, exactRunKey)) {
        opportunities.add(candidate);
      }
    }
    Set<Id> opportunityIds = new Map<Id, Opportunity>(opportunities).keySet();
    List<Contact> contacts = new List<Contact>();
    for (Contact candidate : [
      SELECT Id, Description
      FROM Contact
      WHERE LastName LIKE :namePattern
      LIMIT 9001
    ]) {
      if (matchesRun(candidate.Description, exactRunKey)) {
        contacts.add(candidate);
      }
    }
    Set<Id> contactIds = new Map<Id, Contact>(contacts).keySet();
    List<Account> accounts = new List<Account>();
    for (Account candidate : [
      SELECT Id, Description
      FROM Account
      WHERE Name LIKE :namePattern
      LIMIT 9001
    ]) {
      if (matchesRun(candidate.Description, exactRunKey)) {
        accounts.add(candidate);
      }
    }
    Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();
    List<Lead> leads = new List<Lead>();
    for (Lead candidate : [
      SELECT Id, Description
      FROM Lead
      WHERE LastName LIKE :namePattern
      LIMIT 9001
    ]) {
      if (matchesRun(candidate.Description, exactRunKey)) {
        leads.add(candidate);
      }
    }
    Set<Id> leadIds = new Map<Id, Lead>(leads).keySet();
    Integer plannedDeletes =
      opportunities.size() +
      contacts.size() +
      accounts.size() +
      leads.size();
    assertCleanupSize(plannedDeletes);

    Set<Id> activityWhoIds = new Set<Id>();
    activityWhoIds.addAll(contactIds);
    activityWhoIds.addAll(leadIds);
    Set<Id> activityWhatIds = new Set<Id>();
    activityWhatIds.addAll(accountIds);
    activityWhatIds.addAll(opportunityIds);

    List<Task> taskCandidates = activityWhoIds.isEmpty() &&
      activityWhatIds.isEmpty()
      ? new List<Task>()
      : [
          SELECT Id, Description
          FROM Task
          WHERE WhoId IN :activityWhoIds OR WhatId IN :activityWhatIds
          LIMIT 9001
        ];
    List<Task> tasks = new List<Task>();
    for (Task candidate : taskCandidates) {
      if (matchesRun(candidate.Description, exactRunKey)) {
        tasks.add(candidate);
      }
    }
    List<Event> eventCandidates = activityWhoIds.isEmpty() &&
      activityWhatIds.isEmpty()
      ? new List<Event>()
      : [
          SELECT Id, Description
          FROM Event
          WHERE WhoId IN :activityWhoIds OR WhatId IN :activityWhatIds
          LIMIT 9001
        ];
    List<Event> events = new List<Event>();
    for (Event candidate : eventCandidates) {
      if (matchesRun(candidate.Description, exactRunKey)) {
        events.add(candidate);
      }
    }
    plannedDeletes += tasks.size() + events.size();
    assertCleanupSize(plannedDeletes);
    delete tasks;
    delete events;

    List<OpportunityLineItem> lineItems = opportunityIds.isEmpty()
      ? new List<OpportunityLineItem>()
      : [
          SELECT Id
          FROM OpportunityLineItem
          WHERE OpportunityId IN :opportunityIds
          LIMIT 9001
        ];
    plannedDeletes += lineItems.size();
    assertCleanupSize(plannedDeletes);
    delete lineItems;
    delete opportunities;
    delete contacts;
    delete accounts;
    delete leads;

    List<Product2> productCandidates = [
      SELECT Id, ProductCode, Description, IsActive
      FROM Product2
      WHERE ProductCode LIKE :namePattern
      LIMIT 9001
    ];
    List<Product2> matchedProducts = new List<Product2>();
    for (Product2 candidate : productCandidates) {
      if (matchesRun(candidate.Description, exactRunKey)) {
        matchedProducts.add(candidate);
      }
    }
    Set<Id> matchedProductIds = new Map<Id, Product2>(matchedProducts).keySet();
    List<PricebookEntry> entryCandidates = matchedProductIds.isEmpty()
      ? new List<PricebookEntry>()
      : [
          SELECT Id, Product2Id, Pricebook2.IsStandard, IsActive
          FROM PricebookEntry
          WHERE Product2Id IN :matchedProductIds
          LIMIT 9001
        ];
    Set<Id> protectedProductIds = new Set<Id>();
    for (PricebookEntry entry : entryCandidates) {
      if (!entry.Pricebook2.IsStandard) {
        protectedProductIds.add(entry.Product2Id);
      }
    }

    List<Product2> products = new List<Product2>();
    for (Product2 product : matchedProducts) {
      if (!protectedProductIds.contains(product.Id)) {
        products.add(product);
      } else {
        System.debug(
          LoggingLevel.WARN,
          'Preserved synthetic product with a non-synthetic price book entry: ' +
          product.Id
        );
      }
    }
    Set<Id> productIds = new Map<Id, Product2>(products).keySet();
    List<PricebookEntry> entries = new List<PricebookEntry>();
    for (PricebookEntry entry : entryCandidates) {
      if (
        productIds.contains(entry.Product2Id) && entry.Pricebook2.IsStandard
      ) {
        entries.add(entry);
      }
    }
    plannedDeletes += products.size() + entries.size();
    assertCleanupSize(plannedDeletes);
    for (PricebookEntry entry : entries) {
      entry.IsActive = false;
    }
    update entries;
    for (Product2 product : products) {
      product.IsActive = false;
      product.ProductCode = 'ARCHIVED-' + product.ProductCode;
    }
    update products;

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

  private static Boolean matchesRun(String description, String exactRunKey) {
    String markerPrefix = 'Synthetic sales data; run=SYNTH-';
    if (String.isBlank(description) || !description.startsWith(markerPrefix)) {
      return false;
    }
    return exactRunKey == null
      ? true
      : description == 'Synthetic sales data; run=' + exactRunKey;
  }

  private static void assertCleanupSize(Integer plannedDeletes) {
    if (plannedDeletes > 9000) {
      throw new SyntheticDataException(
        'Cleanup would delete more than 9,000 rows. Clean individual runs or use Batch Apex.'
      );
    }
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
    if (!orgInfo.IsSandbox && orgInfo.OrganizationType != 'Developer Edition') {
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
        ' deactivated price book entries, and ' +
        productCount +
        ' deactivated products.';
    }
  }
}
