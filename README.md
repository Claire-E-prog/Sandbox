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

The generator uses Apex schema describe information at runtime. It discovers
the org's active Opportunity stages and writable custom fields on every object
it creates. Active custom picklist values are distributed across records;
common custom field types receive deterministic synthetic values. Formula,
auto-number, defaulted, and read-only fields are left to Salesforce. Optional
unsupported fields, such as lookups, are logged and skipped; a required
unsupported field stops the transaction with its API name so an org-specific
value can be added safely.

All record names receive a unique `SYNTH-...` run key, and execution is refused
outside Developer Edition and sandbox orgs. Edit the four count variables at
the top of the file to change the data volume.

Remove all generated records with:

```bash
sf apex run \
  --file scripts/apex/cleanup-sales-data.apex \
  --target-org <org-alias>
```

The cleanup script moves matching records to the recycle bin. Its pattern can
be narrowed to a single run key before execution.

Validation rules, dependent-picklist relationships, flows, triggers, and
semantic requirements cannot be inferred reliably from describe metadata and
can still prevent inserts. Add explicit constructor values when an org requires
them.
