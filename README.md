# Salesforce synthetic sales data

This Salesforce DX project generates a manufacturing-oriented sales dataset in
a Developer Edition or sandbox org.

## Structure

Reusable logic lives in deployable Apex classes:

- `SyntheticDataConfig` centralizes record counts and scenario values.
- Object factories generate Accounts and Contacts, Leads, Products,
  Opportunities and line items, and Activities.
- `SyntheticSchemaValueFactory` discovers writable custom fields and active
  picklist values.
- `SyntheticOwnerResolver` validates configured owners.
- `SyntheticSalesDataService` orchestrates a complete transactional run.
- `SyntheticSalesDataCleanup` removes one run or all generated runs.

Small anonymous Apex files under `scripts/apex` serve as entry points:

- `generate-sales-data.apex` generates the complete dataset.
- `generate-accounts-contacts.apex` isolates account/contact generation.
- `generate-leads.apex` isolates Lead generation.
- `generate-sales-pipeline.apex` generates Accounts, Contacts, Products,
  Opportunities, and line items.
- `generate-activities.apex` generates a small related dataset for debugging
  Tasks and Events.
- `cleanup-sales-data.apex` removes generated data.

## Customize the manufacturing scenario

Edit `SyntheticDataConfig.cls` to change reusable scenario defaults:

- Manufacturer and plant names
- Cities and preferred Industry values
- Buyer and operations job titles
- Product names, SKUs, and prices
- Opportunity themes, quantities, and sales-cycle lengths
- Company revenue and employee ranges
- Activity subjects and record counts

For a one-off run, override config values in an entry script:

```apex
SyntheticDataConfig config = SyntheticDataConfig.manufacturing();
config.ownerUsernames = new List<String>{
  'rep.one@example.com',
  'rep.two@example.com'
};
config.accountCount = 30;
config.minimumAnnualRevenue = 10000000;

SyntheticSalesDataService.generateAll(config);
```

Preferred values are used only when they are active in the target org. The
factories otherwise fall back to active org picklist values.

## Deploy and run

Deploy the classes:

```bash
sf project deploy start --source-dir force-app --target-org <org-alias>
```

Add exact Salesforce usernames to the selected entry script, then execute it:

```bash
sf apex run \
  --file scripts/apex/generate-sales-data.apex \
  --target-org <org-alias>
```

The owners must be active and licensed to own the generated record types. The
running user must also be allowed to assign records to them.

Run an isolated entry script while debugging a factory:

```bash
sf apex run \
  --file scripts/apex/generate-leads.apex \
  --target-org <org-alias>
```

## Cleanup

Remove every generated run:

```bash
sf apex run \
  --file scripts/apex/cleanup-sales-data.apex \
  --target-org <org-alias>
```

To remove one run, call:

```apex
SyntheticSalesDataCleanup.cleanupRun('SYNTH-20260717-001122123');
```

Generated names and product codes start with a unique `SYNTH-...` run key.
Cleanup moves records to the recycle bin.

## Custom schema behavior

Factories inspect writable custom fields at runtime. Active custom picklist
values and common scalar field types receive deterministic values. Formula,
auto-number, defaulted, and read-only fields are left to Salesforce. Optional
unsupported fields such as lookups are logged and skipped; required unsupported
fields stop and roll back a complete run.

Validation rules, dependent picklists, flows, triggers, and semantic
requirements cannot be inferred reliably from describe metadata. Add explicit
field values in the relevant object factory when the target org requires them.

## Tests

After deployment, run:

```bash
sf apex run test \
  --class-names SyntheticSalesDataServiceTest \
  --result-format human \
  --target-org <org-alias>
```
