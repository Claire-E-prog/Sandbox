SyntheticDataConfig config = SyntheticDataConfig.manufacturing();
config.ownerUsernames = new List<String>{ UserInfo.getUserName() };

// Activities need related records. Keep these low while debugging.
config.accountCount = 2;
config.contactsPerAccount = 1;
config.opportunitiesPerAccount = 1;
config.leadCount = 2;
config.taskCount = 4;
config.eventCount = 2;

SyntheticDataRun run = SyntheticSalesDataService.start(config);
SyntheticAccountContactFactory.create(config, run);
SyntheticLeadFactory.create(config, run);
SyntheticProductFactory.create(config, run);
SyntheticOpportunityFactory.create(config, run);
SyntheticActivityFactory.create(config, run);
SyntheticSalesDataService.logSummary(run);
