// Deploy the Apex classes first:
//   sf project deploy start --source-dir force-app --target-org <alias>
//
// Then configure owners and run:
//   sf apex run --file scripts/apex/generate-sales-data.apex --target-org <alias>
SyntheticDataConfig config = SyntheticDataConfig.manufacturing();
config.ownerUsernames = new List<String>{
  // 'sales.rep.one@example.com',
  // 'sales.rep.two@example.com'
};

// Override scenario settings here when a run needs different volumes.
// config.accountCount = 20;
// config.contactsPerAccount = 2;
// config.opportunitiesPerAccount = 3;
// config.leadCount = 20;
// config.taskCount = 40;
// config.eventCount = 20;

SyntheticSalesDataService.generateAll(config);
