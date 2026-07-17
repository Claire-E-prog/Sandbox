// Removes records created by generate-sales-data.apex.
// Run with:
//   sf apex run --file scripts/apex/cleanup-sales-data.apex --target-org <alias>
//
// To remove only one run, replace 'SYNTH-%' with its complete run key plus '%',
// for example: 'SYNTH-20260717-001122123%'.

Organization orgInfo = [
    SELECT IsSandbox, OrganizationType
    FROM Organization
    LIMIT 1
];
if (!orgInfo.IsSandbox && orgInfo.OrganizationType != 'Developer Edition') {
    throw new IllegalArgumentException(
        'Synthetic data cleanup is allowed only in a sandbox or Developer Edition org.'
    );
}

String syntheticNamePattern = 'SYNTH-%';

List<Opportunity> opportunities = [
    SELECT Id
    FROM Opportunity
    WHERE Name LIKE :syntheticNamePattern
];
Set<Id> opportunityIds = new Map<Id, Opportunity>(opportunities).keySet();

List<Contact> contacts = [
    SELECT Id
    FROM Contact
    WHERE LastName LIKE :syntheticNamePattern
];
Set<Id> contactIds = new Map<Id, Contact>(contacts).keySet();

List<Account> accounts = [
    SELECT Id
    FROM Account
    WHERE Name LIKE :syntheticNamePattern
];
Set<Id> accountIds = new Map<Id, Account>(accounts).keySet();

List<Lead> leads = [
    SELECT Id
    FROM Lead
    WHERE LastName LIKE :syntheticNamePattern
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
    WHERE ProductCode LIKE :syntheticNamePattern
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

System.debug(LoggingLevel.WARN,
    'Synthetic sales data moved to the recycle bin: ' +
    tasks.size() + ' tasks, ' +
    events.size() + ' events, ' +
    lineItems.size() + ' line items, ' +
    opportunities.size() + ' opportunities, ' +
    leads.size() + ' leads, ' +
    contacts.size() + ' contacts, ' +
    accounts.size() + ' accounts, ' +
    entries.size() + ' price book entries, and ' +
    products.size() + ' products.'
);
