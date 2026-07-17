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
                generatedValue = activeValues[(sequence - 1) % activeValues.size()];
            }
        } else if (fieldType == Schema.DisplayType.Boolean) {
            generatedValue = false;
        } else if (fieldType == Schema.DisplayType.Date) {
            generatedValue = Date.today().addDays(-(sequence % 30));
        } else if (fieldType == Schema.DisplayType.DateTime) {
            generatedValue = Datetime.now().addDays(-(sequence % 30));
        } else if (fieldType == Schema.DisplayType.Time) {
            generatedValue = Time.newInstance(9 + (sequence % 8), 0, 0, 0);
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
            generatedValue = 'synthetic+' + String.valueOf(sequence) +
                '@example.invalid';
        } else if (fieldType == Schema.DisplayType.Phone) {
            generatedValue = '+1 555 010 ' +
                String.valueOf(1000 + (sequence % 9000));
        } else if (fieldType == Schema.DisplayType.Url) {
            generatedValue = 'https://example.invalid/synthetic/' +
                String.valueOf(sequence);
        } else if (
            fieldType == Schema.DisplayType.String ||
            fieldType == Schema.DisplayType.TextArea ||
            fieldType == Schema.DisplayType.EncryptedString ||
            fieldType == Schema.DisplayType.ComboBox
        ) {
            String textValue = String.valueOf(sequence) + '-' +
                fieldApiName + '-' + runKey;
            Integer maximumLength = field.getLength();
            generatedValue = maximumLength > 0 && textValue.length() > maximumLength
                ? textValue.substring(0, maximumLength)
                : textValue;
        }

        if (generatedValue != null) {
            record.put(fieldApiName, generatedValue);
        } else if (!field.isNillable()) {
            throw new IllegalArgumentException(
                'Cannot synthesize required custom field ' +
                record.getSObjectType().getDescribe().getName() + '.' +
                fieldApiName + ' (' + String.valueOf(fieldType) + '). ' +
                'Add an org-specific value to the record constructor.'
            );
        } else if (sequence == 1) {
            System.debug(LoggingLevel.WARN,
                'Skipped unsupported optional custom field ' +
                record.getSObjectType().getDescribe().getName() + '.' +
                fieldApiName + ' (' + String.valueOf(fieldType) + ').'
            );
        }
    }
}

Integer accountCount = 20;
Integer contactsPerAccount = 2;
Integer opportunitiesPerAccount = 3;
Integer productCount = 5;

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
    throw new IllegalArgumentException('The org has no active Opportunity stages.');
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
    throw new IllegalArgumentException('The org needs at least one active open Opportunity stage.');
}

// Accounts
List<Account> accounts = new List<Account>();
List<String> industries = new List<String>();
for (Schema.PicklistEntry entry :
    Account.Industry.getDescribe().getPicklistValues()
) {
    if (entry.isActive()) {
        industries.add(entry.getValue());
    }
}
for (Integer i = 0; i < accountCount; i++) {
    Account account = new Account(
        Name = runKey + '-Account-' + String.valueOf(i + 1),
        BillingCity = 'Demo City ' + String.valueOf((i % 5) + 1),
        BillingCountry = 'United States',
        NumberOfEmployees = 25 + (i * 17),
        AnnualRevenue = 500000 + (i * 125000),
        Description = marker
    );
    if (!industries.isEmpty()) {
        account.Industry = industries[i % industries.size()];
    }
    populateCustomFields(account, runKey, i + 1);
    accounts.add(account);
}
insert accounts;

// Contacts
List<Contact> contacts = new List<Contact>();
for (Integer accountIndex = 0; accountIndex < accounts.size(); accountIndex++) {
    for (Integer contactIndex = 0; contactIndex < contactsPerAccount; contactIndex++) {
        Integer sequence = (accountIndex * contactsPerAccount) + contactIndex + 1;
        Contact contact = new Contact(
            AccountId = accounts[accountIndex].Id,
            FirstName = 'Demo' + String.valueOf(sequence),
            LastName = runKey + '-Contact',
            Email = 'synthetic+' + runKey.toLowerCase() + '-' +
                String.valueOf(sequence) + '@example.invalid',
            Title = contactIndex == 0 ? 'Decision Maker' : 'Evaluator',
            Description = marker
        );
        populateCustomFields(contact, runKey, sequence);
        contacts.add(contact);
    }
}
insert contacts;

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
    for (Integer opportunityIndex = 0;
        opportunityIndex < opportunitiesPerAccount;
        opportunityIndex++
    ) {
        Integer sequence = (accountIndex * opportunitiesPerAccount) + opportunityIndex;
        Integer outcomeBucket = sequence % 10;
        String stageName;
        Date closeDate;

        if (outcomeBucket < 2 && !wonStages.isEmpty()) {
            stageName = wonStages[sequence % wonStages.size()];
            closeDate = today.addDays(-7 - (sequence % 90));
        } else if (outcomeBucket < 4 && !lostStages.isEmpty()) {
            stageName = lostStages[sequence % lostStages.size()];
            closeDate = today.addDays(-7 - (sequence % 90));
        } else {
            stageName = openStages[sequence % openStages.size()];
            closeDate = today.addDays(14 + (sequence % 120));
        }

        Opportunity opportunity = new Opportunity(
            AccountId = accounts[accountIndex].Id,
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
    PricebookEntry entry = pricebookEntries[i % pricebookEntries.size()];
    OpportunityLineItem lineItem = new OpportunityLineItem(
        OpportunityId = opportunities[i].Id,
        PricebookEntryId = entry.Id,
        Quantity = 1 + (i % 8),
        UnitPrice = entry.UnitPrice,
        Description = marker
    );
    populateCustomFields(lineItem, runKey, i + 1);
    lineItems.add(lineItem);
}
insert lineItems;

System.debug(LoggingLevel.WARN, 'Synthetic sales data created: ' + runKey);
System.debug(LoggingLevel.WARN,
    accounts.size() + ' accounts, ' +
    contacts.size() + ' contacts, ' +
    products.size() + ' products, ' +
    opportunities.size() + ' opportunities, and ' +
    lineItems.size() + ' opportunity line items.'
);
