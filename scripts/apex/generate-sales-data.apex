// Generates a small, deterministic sales pipeline and populates supported
// writable custom fields discovered through Apex schema describe information.
// Run with:
//   sf apex run --file scripts/apex/generate-sales-data.apex --target-org <alias>
//
// Adjust these values before running. Keep the resulting row count below the
// execute-anonymous transaction limits, or adapt this example to Batch Apex.
void populateCustomFields(SObject record, String runKey, Integer sequence) {
  Map<String, Schema.SObjectField> fields = record.getSObjectType()
    .getDescribe()
    .fields
    .getMap();

  for (String fieldApiName : fields.keySet()) {
    Schema.DescribeFieldResult field = fields.get(fieldApiName).getDescribe();
    if (
      !field.isCustom() ||
      !field.isCreateable() ||
      field.isCalculated() ||
      field.isAutoNumber() ||
      field.isDefaultedOnCreate() ||
      record.get(fieldApiName) != null
    ) {
      continue;
    }

    Schema.DisplayType fieldType = field.getType();
    Object generatedValue;

    if (
      fieldType == Schema.DisplayType.Picklist ||
      fieldType == Schema.DisplayType.MultiPicklist
    ) {
      List<String> activeValues = new List<String>();
      for (Schema.PicklistEntry option : field.getPicklistValues()) {
        if (option.isActive()) {
          activeValues.add(option.getValue());
        }
      }
      if (!activeValues.isEmpty()) {
        generatedValue = activeValues[
          Math.mod(sequence - 1, activeValues.size())
        ];
      }
    } else if (fieldType == Schema.DisplayType.Boolean) {
      generatedValue = false;
    } else if (fieldType == Schema.DisplayType.Date) {
      generatedValue = Date.today().addDays(-Math.mod(sequence, 30));
    } else if (fieldType == Schema.DisplayType.DateTime) {
      generatedValue = Datetime.now().addDays(-Math.mod(sequence, 30));
    } else if (fieldType == Schema.DisplayType.Time) {
      generatedValue = Time.newInstance(9 + Math.mod(sequence, 8), 0, 0, 0);
    } else if (fieldType == Schema.DisplayType.Integer) {
      generatedValue = sequence;
    } else if (fieldType == Schema.DisplayType.Long) {
      generatedValue = Long.valueOf(String.valueOf(sequence));
    } else if (
      fieldType == Schema.DisplayType.Currency ||
      fieldType == Schema.DisplayType.Double ||
      fieldType == Schema.DisplayType.Percent
    ) {
      generatedValue = Decimal.valueOf(sequence);
    } else if (fieldType == Schema.DisplayType.Email) {
      generatedValue =
        'synthetic+' +
        String.valueOf(sequence) +
        '@example.invalid';
    } else if (fieldType == Schema.DisplayType.Phone) {
      generatedValue =
        '+1 555 010 ' + String.valueOf(1000 + Math.mod(sequence, 9000));
    } else if (fieldType == Schema.DisplayType.Url) {
      generatedValue =
        'https://example.invalid/synthetic/' + String.valueOf(sequence);
    } else if (
      fieldType == Schema.DisplayType.String ||
      fieldType == Schema.DisplayType.TextArea ||
      fieldType == Schema.DisplayType.EncryptedString ||
      fieldType == Schema.DisplayType.ComboBox
    ) {
      String textValue =
        String.valueOf(sequence) +
        '-' +
        fieldApiName +
        '-' +
        runKey;
      Integer maximumLength = field.getLength();
      generatedValue = maximumLength > 0 &&
        textValue.length() > maximumLength
        ? textValue.substring(0, maximumLength)
        : textValue;
    }

    if (generatedValue != null) {
      record.put(fieldApiName, generatedValue);
    } else if (!field.isNillable()) {
      throw new IllegalArgumentException(
        'Cannot synthesize required custom field ' +
          record.getSObjectType().getDescribe().getName() +
          '.' +
          fieldApiName +
          ' (' +
          String.valueOf(fieldType) +
          '). ' +
          'Add an org-specific value to the record constructor.'
      );
    } else if (sequence == 1) {
      System.debug(
        LoggingLevel.WARN,
        'Skipped unsupported optional custom field ' +
          record.getSObjectType().getDescribe().getName() +
          '.' +
          fieldApiName +
          ' (' +
          String.valueOf(fieldType) +
          ').'
      );
    }
  }
}

List<String> activePicklistValues(Schema.SObjectField fieldToken) {
  List<String> values = new List<String>();
  for (
    Schema.PicklistEntry option : fieldToken.getDescribe().getPicklistValues()
  ) {
    if (option.isActive()) {
      values.add(option.getValue());
    }
  }
  return values;
}

Integer accountCount = 20;
Integer contactsPerAccount = 2;
Integer opportunitiesPerAccount = 3;
Integer productCount = 5;
Integer leadCount = 20;
Integer taskCount = 40;
Integer eventCount = 20;

// Add the exact Salesforce usernames that should own generated records.
// Usernames are globally unique and safer than matching users by name or email.
List<String> ownerUsernames = new List<String>{};
// 'sales.rep.one@example.com',
// 'sales.rep.two@example.com'

// Developer Edition orgs are not reported as sandboxes, so allow both.
Organization orgInfo = [
  SELECT IsSandbox, OrganizationType
  FROM Organization
  LIMIT 1
];
if (!orgInfo.IsSandbox && orgInfo.OrganizationType != 'Developer Edition') {
  throw new IllegalArgumentException(
    'Synthetic data generation is allowed only in a sandbox or Developer Edition org.'
  );
}

if (ownerUsernames.isEmpty()) {
  throw new IllegalArgumentException(
    'Add at least one Salesforce username to ownerUsernames before running.'
  );
}

Set<String> requestedUsernames = new Set<String>();
Set<String> normalizedUsernames = new Set<String>();
for (String username : ownerUsernames) {
  if (String.isBlank(username)) {
    throw new IllegalArgumentException(
      'ownerUsernames cannot contain a blank value.'
    );
  }

  String trimmedUsername = username.trim();
  String normalizedUsername = trimmedUsername.toLowerCase();
  if (normalizedUsernames.contains(normalizedUsername)) {
    throw new IllegalArgumentException(
      'Duplicate username in ownerUsernames: ' + trimmedUsername
    );
  }
  requestedUsernames.add(trimmedUsername);
  normalizedUsernames.add(normalizedUsername);
}

Map<String, User> usersByNormalizedUsername = new Map<String, User>();
for (User owner : [
  SELECT Id, Username, IsActive
  FROM User
  WHERE Username IN :requestedUsernames
]) {
  usersByNormalizedUsername.put(owner.Username.toLowerCase(), owner);
}

List<Id> ownerIds = new List<Id>();
for (String username : ownerUsernames) {
  User owner = usersByNormalizedUsername.get(username.trim().toLowerCase());
  if (owner == null) {
    throw new IllegalArgumentException(
      'No Salesforce user found for username: ' + username
    );
  }
  if (!owner.IsActive) {
    throw new IllegalArgumentException(
      'Synthetic data owner is inactive: ' + username
    );
  }
  ownerIds.add(owner.Id);
}

String runKey = 'SYNTH-' + Datetime.now().formatGmt('yyyyMMdd-HHmmssSSS');
String marker = 'Synthetic sales data; run=' + runKey;

// Discover stage names instead of assuming an org uses Salesforce defaults.
List<OpportunityStage> stages = [
  SELECT MasterLabel, IsClosed, IsWon
  FROM OpportunityStage
  WHERE IsActive = TRUE
  ORDER BY SortOrder
];
if (stages.isEmpty()) {
  throw new IllegalArgumentException(
    'The org has no active Opportunity stages.'
  );
}

List<String> openStages = new List<String>();
List<String> wonStages = new List<String>();
List<String> lostStages = new List<String>();
for (OpportunityStage stage : stages) {
  if (!stage.IsClosed) {
    openStages.add(stage.MasterLabel);
  } else if (stage.IsWon) {
    wonStages.add(stage.MasterLabel);
  } else {
    lostStages.add(stage.MasterLabel);
  }
}
if (openStages.isEmpty()) {
  throw new IllegalArgumentException(
    'The org needs at least one active open Opportunity stage.'
  );
}

// Accounts
List<Account> accounts = new List<Account>();
List<String> industries = new List<String>();
for (
  Schema.PicklistEntry entry : Account.Industry.getDescribe()
    .getPicklistValues()
) {
  if (entry.isActive()) {
    industries.add(entry.getValue());
  }
}
for (Integer i = 0; i < accountCount; i++) {
  Account account = new Account(
    Name = runKey + '-Account-' + String.valueOf(i + 1),
    OwnerId = ownerIds[Math.mod(i, ownerIds.size())],
    BillingCity = 'Demo City ' + String.valueOf(Math.mod(i, 5) + 1),
    BillingCountry = 'United States',
    NumberOfEmployees = 25 + (i * 17),
    AnnualRevenue = 500000 + (i * 125000),
    Description = marker
  );
  if (!industries.isEmpty()) {
    account.Industry = industries[Math.mod(i, industries.size())];
  }
  populateCustomFields(account, runKey, i + 1);
  accounts.add(account);
}
insert accounts;

// Contacts
List<Contact> contacts = new List<Contact>();
for (Integer accountIndex = 0; accountIndex < accounts.size(); accountIndex++) {
  for (
    Integer contactIndex = 0; contactIndex < contactsPerAccount; contactIndex++
  ) {
    Integer sequence = (accountIndex * contactsPerAccount) + contactIndex + 1;
    Contact contact = new Contact(
      AccountId = accounts[accountIndex].Id,
      OwnerId = ownerIds[Math.mod(sequence - 1, ownerIds.size())],
      FirstName = 'Demo' + String.valueOf(sequence),
      LastName = runKey + '-Contact',
      Email = 'synthetic+' +
        runKey.toLowerCase() +
        '-' +
        String.valueOf(sequence) +
        '@example.invalid',
      Title = contactIndex == 0 ? 'Decision Maker' : 'Evaluator',
      Description = marker
    );
    populateCustomFields(contact, runKey, sequence);
    contacts.add(contact);
  }
}
insert contacts;

// Leads use the org's active, non-converted statuses.
Set<String> activeLeadStatusValues = new Set<String>(
  activePicklistValues(Lead.Status)
);
List<String> leadStatuses = new List<String>();
for (LeadStatus status : [
  SELECT ApiName
  FROM LeadStatus
  WHERE IsConverted = FALSE
  ORDER BY SortOrder
]) {
  if (activeLeadStatusValues.contains(status.ApiName)) {
    leadStatuses.add(status.ApiName);
  }
}
if (leadStatuses.isEmpty()) {
  throw new IllegalArgumentException(
    'The org needs at least one active, non-converted Lead status.'
  );
}

List<String> leadIndustries = activePicklistValues(Lead.Industry);
List<Lead> leads = new List<Lead>();
for (Integer i = 0; i < leadCount; i++) {
  Lead lead = new Lead(
    OwnerId = ownerIds[Math.mod(i, ownerIds.size())],
    FirstName = 'Prospect' + String.valueOf(i + 1),
    LastName = runKey + '-Lead',
    Company = runKey + '-Prospect-Company-' + String.valueOf(i + 1),
    Email = 'synthetic+' +
      runKey.toLowerCase() +
      '-lead-' +
      String.valueOf(i + 1) +
      '@example.invalid',
    Status = leadStatuses[Math.mod(i, leadStatuses.size())],
    Description = marker
  );
  if (!leadIndustries.isEmpty()) {
    lead.Industry = leadIndustries[Math.mod(i, leadIndustries.size())];
  }
  populateCustomFields(lead, runKey, i + 1);
  leads.add(lead);
}
insert leads;

// Products and entries in the standard price book
Pricebook2 standardPricebook = [
  SELECT Id, IsActive
  FROM Pricebook2
  WHERE IsStandard = TRUE
  LIMIT 1
];
if (!standardPricebook.IsActive) {
  standardPricebook.IsActive = true;
  update standardPricebook;
}

List<Product2> products = new List<Product2>();
for (Integer i = 0; i < productCount; i++) {
  Product2 product = new Product2(
    Name = runKey + '-Product-' + String.valueOf(i + 1),
    ProductCode = runKey + '-SKU-' + String.valueOf(i + 1),
    IsActive = true,
    Description = marker
  );
  populateCustomFields(product, runKey, i + 1);
  products.add(product);
}
insert products;

List<PricebookEntry> pricebookEntries = new List<PricebookEntry>();
for (Integer i = 0; i < products.size(); i++) {
  PricebookEntry pricebookEntry = new PricebookEntry(
    Pricebook2Id = standardPricebook.Id,
    Product2Id = products[i].Id,
    UnitPrice = 500 + (i * 350),
    IsActive = true
  );
  populateCustomFields(pricebookEntry, runKey, i + 1);
  pricebookEntries.add(pricebookEntry);
}
insert pricebookEntries;

// Opportunities: 60% open, 20% won, and 20% lost when closed stages exist.
List<Opportunity> opportunities = new List<Opportunity>();
Date today = Date.today();
for (Integer accountIndex = 0; accountIndex < accounts.size(); accountIndex++) {
  for (
    Integer opportunityIndex = 0;
    opportunityIndex < opportunitiesPerAccount;
    opportunityIndex++
  ) {
    Integer sequence =
      (accountIndex * opportunitiesPerAccount) + opportunityIndex;
    Integer outcomeBucket = Math.mod(sequence, 10);
    String stageName;
    Date closeDate;

    if (outcomeBucket < 2 && !wonStages.isEmpty()) {
      stageName = wonStages[Math.mod(sequence, wonStages.size())];
      closeDate = today.addDays(-7 - Math.mod(sequence, 90));
    } else if (outcomeBucket < 4 && !lostStages.isEmpty()) {
      stageName = lostStages[Math.mod(sequence, lostStages.size())];
      closeDate = today.addDays(-7 - Math.mod(sequence, 90));
    } else {
      stageName = openStages[Math.mod(sequence, openStages.size())];
      closeDate = today.addDays(14 + Math.mod(sequence, 120));
    }

    Opportunity opportunity = new Opportunity(
      AccountId = accounts[accountIndex].Id,
      OwnerId = ownerIds[Math.mod(sequence, ownerIds.size())],
      Name = runKey + '-Opportunity-' + String.valueOf(sequence + 1),
      StageName = stageName,
      CloseDate = closeDate,
      Pricebook2Id = standardPricebook.Id,
      Description = marker
    );
    populateCustomFields(opportunity, runKey, sequence + 1);
    opportunities.add(opportunity);
  }
}
insert opportunities;

// One line item per opportunity. Salesforce derives each Opportunity Amount
// from its line items.
List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();
for (Integer i = 0; i < opportunities.size(); i++) {
  PricebookEntry entry = pricebookEntries[Math.mod(i, pricebookEntries.size())];
  OpportunityLineItem lineItem = new OpportunityLineItem(
    OpportunityId = opportunities[i].Id,
    PricebookEntryId = entry.Id,
    Quantity = 1 + Math.mod(i, 8),
    UnitPrice = entry.UnitPrice,
    Description = marker
  );
  populateCustomFields(lineItem, runKey, i + 1);
  lineItems.add(lineItem);
}
insert lineItems;

// Tasks and Events are both Salesforce activities. Activities alternate
// between generated Contacts and Leads; Lead activities intentionally omit
// WhatId because Salesforce does not allow WhatId when WhoId is a Lead.
List<String> taskSubjects = activePicklistValues(Task.Subject);
if (taskSubjects.isEmpty()) {
  taskSubjects.add('Synthetic follow-up');
}
List<String> taskStatuses = activePicklistValues(Task.Status);
List<String> taskPriorities = activePicklistValues(Task.Priority);
if (taskStatuses.isEmpty() || taskPriorities.isEmpty()) {
  throw new IllegalArgumentException(
    'The org needs active Task status and priority values.'
  );
}

List<Task> tasks = new List<Task>();
for (Integer i = 0; i < taskCount; i++) {
  Task task = new Task(
    OwnerId = ownerIds[Math.mod(i, ownerIds.size())],
    Subject = taskSubjects[Math.mod(i, taskSubjects.size())],
    Status = taskStatuses[Math.mod(i, taskStatuses.size())],
    Priority = taskPriorities[Math.mod(i, taskPriorities.size())],
    ActivityDate = Date.today().addDays(-14 + Math.mod(i, 45)),
    Description = marker
  );

  Boolean useLead =
    !leads.isEmpty() && (contacts.isEmpty() || Math.mod(i, 2) == 1);
  if (useLead) {
    task.WhoId = leads[Math.mod(i, leads.size())].Id;
  } else if (!contacts.isEmpty()) {
    task.WhoId = contacts[Math.mod(i, contacts.size())].Id;
    if (!opportunities.isEmpty()) {
      task.WhatId = opportunities[Math.mod(i, opportunities.size())].Id;
    }
  } else if (!accounts.isEmpty()) {
    task.WhatId = accounts[Math.mod(i, accounts.size())].Id;
  }

  populateCustomFields(task, runKey, i + 1);
  tasks.add(task);
}
insert tasks;

List<String> eventSubjects = activePicklistValues(Event.Subject);
if (eventSubjects.isEmpty()) {
  eventSubjects.add('Synthetic meeting');
}

List<Event> events = new List<Event>();
for (Integer i = 0; i < eventCount; i++) {
  Datetime startTime = Datetime.now()
    .addDays(-10 + Math.mod(i, 30))
    .addHours(9 + Math.mod(i, 8));
  Event event = new Event(
    OwnerId = ownerIds[Math.mod(i, ownerIds.size())],
    Subject = eventSubjects[Math.mod(i, eventSubjects.size())],
    StartDateTime = startTime,
    EndDateTime = startTime.addMinutes(30 + (Math.mod(i, 3) * 30)),
    Description = marker
  );

  Boolean useLead =
    !leads.isEmpty() && (contacts.isEmpty() || Math.mod(i, 2) == 1);
  if (useLead) {
    event.WhoId = leads[Math.mod(i, leads.size())].Id;
  } else if (!contacts.isEmpty()) {
    event.WhoId = contacts[Math.mod(i, contacts.size())].Id;
    if (!opportunities.isEmpty()) {
      event.WhatId = opportunities[Math.mod(i, opportunities.size())].Id;
    }
  } else if (!accounts.isEmpty()) {
    event.WhatId = accounts[Math.mod(i, accounts.size())].Id;
  }

  populateCustomFields(event, runKey, i + 1);
  events.add(event);
}
insert events;

System.debug(LoggingLevel.WARN, 'Synthetic sales data created: ' + runKey);
System.debug(
  LoggingLevel.WARN,
  accounts.size() +
    ' accounts, ' +
    contacts.size() +
    ' contacts, ' +
    products.size() +
    ' products, ' +
    leads.size() +
    ' leads, ' +
    opportunities.size() +
    ' opportunities, ' +
    lineItems.size() +
    ' opportunity line items, ' +
    tasks.size() +
    ' tasks, and ' +
    events.size() +
    ' events.'
);
