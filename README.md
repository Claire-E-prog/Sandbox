# Sandbox
Sandbox repo for trying out cursor

## Salesforce synthetic sales data

The anonymous Apex scripts in [`scripts/apex`](scripts/apex) generate and
remove a sample sales pipeline built from standard Salesforce objects:

- Accounts and contacts
- Products and standard price book entries
- Open, won, and lost opportunities
- Opportunity line items

Authenticate a Developer Edition or sandbox org, then run:

```bash
sf apex run \
  --file scripts/apex/generate-sales-data.apex \
  --target-org <org-alias>
```

The generator discovers the org's active Opportunity stage names, prefixes all
record names with a unique `SYNTH-...` run key, and refuses to run in other org
types. Edit the four count variables at the top of the file to change the data
volume.

Remove all generated records with:

```bash
sf apex run \
  --file scripts/apex/cleanup-sales-data.apex \
  --target-org <org-alias>
```

The cleanup script moves matching records to the recycle bin. Its pattern can
be narrowed to a single run key before execution.

Org-specific validation rules, required custom fields, flows, and triggers can
still prevent inserts. Extend the record constructors when the target org
requires additional values.
