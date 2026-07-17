SyntheticDataConfig config = SyntheticDataConfig.manufacturing();
config.ownerUsernames = new List<String>{
  // 'sales.rep.one@example.com'
};

SyntheticDataRun run = SyntheticSalesDataService.start(config);
SyntheticAccountContactFactory.create(config, run);
SyntheticProductFactory.create(config, run);
SyntheticOpportunityFactory.create(config, run);
SyntheticSalesDataService.logSummary(run);
