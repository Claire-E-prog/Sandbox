SyntheticDataConfig config = SyntheticDataConfig.manufacturing();
config.ownerUsernames = new List<String>{ UserInfo.getUserName() };

SyntheticDataRun run = SyntheticSalesDataService.start(config);
SyntheticLeadFactory.create(config, run);
SyntheticSalesDataService.logSummary(run);
