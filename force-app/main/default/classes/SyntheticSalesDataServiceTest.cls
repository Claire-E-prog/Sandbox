@IsTest
private class SyntheticSalesDataServiceTest {
  @IsTest
  static void generatesManufacturingScenario() {
    SyntheticDataConfig config = smallConfig();

    Test.startTest();
    SyntheticDataRun run = SyntheticSalesDataService.generateAll(config);
    Test.stopTest();

    System.assert(run.runKey.startsWith('SYNTH-'));
    System.assertEquals(2, run.accounts.size());
    System.assertEquals(2, run.contacts.size());
    System.assertEquals(2, run.leads.size());
    System.assertEquals(config.products.size(), run.products.size());
    System.assertEquals(2, run.opportunities.size());
    System.assertEquals(2, run.lineItems.size());
    System.assertEquals(2, run.tasks.size());
    System.assertEquals(2, run.events.size());
    System.assertEquals(UserInfo.getUserId(), run.accounts[0].OwnerId);
    System.assert(run.products[0].ProductCode.startsWith(run.runKey));
  }

  @IsTest
  static void cleansUpOneRun() {
    SyntheticDataConfig config = smallConfig();
    config.opportunitiesPerAccount = 0;
    config.taskCount = 0;
    config.eventCount = 0;

    SyntheticDataRun run = SyntheticSalesDataService.start(config);
    SyntheticAccountContactFactory.create(config, run);
    SyntheticLeadFactory.create(config, run);

    Test.startTest();
    SyntheticSalesDataCleanup.CleanupResult result = SyntheticSalesDataCleanup.cleanupRun(
      run.runKey
    );
    Test.stopTest();

    System.assertEquals(2, result.accountCount);
    System.assertEquals(2, result.contactCount);
    System.assertEquals(2, result.leadCount);
    String runPattern = run.runKey + '%';
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Account WHERE Name LIKE :runPattern]
    );
  }

  @IsTest
  static void rejectsDuplicateOwners() {
    SyntheticDataConfig config = SyntheticDataConfig.manufacturing();
    String username = [
      SELECT Username
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ].Username;
    config.ownerUsernames = new List<String>{ username, username };

    try {
      SyntheticSalesDataService.start(config);
      System.assert(false, 'Expected duplicate owners to be rejected.');
    } catch (SyntheticDataException error) {
      System.assert(error.getMessage().contains('Duplicate username'));
    }
  }

  private static SyntheticDataConfig smallConfig() {
    SyntheticDataConfig config = SyntheticDataConfig.manufacturing();
    config.ownerUsernames = new List<String>{
      [
        SELECT Username
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ].Username
    };
    config.accountCount = 2;
    config.contactsPerAccount = 1;
    config.opportunitiesPerAccount = 1;
    config.leadCount = 2;
    config.taskCount = 2;
    config.eventCount = 2;
    return config;
  }
}
