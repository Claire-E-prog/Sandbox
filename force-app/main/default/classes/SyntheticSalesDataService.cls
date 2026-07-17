public without sharing class SyntheticSalesDataService {
  public static SyntheticDataRun generateAll(SyntheticDataConfig config) {
    Savepoint savepoint = Database.setSavepoint();
    try {
      SyntheticDataRun run = start(config);
      SyntheticAccountContactFactory.create(config, run);
      SyntheticLeadFactory.create(config, run);
      SyntheticProductFactory.create(config, run);
      SyntheticOpportunityFactory.create(config, run);
      SyntheticActivityFactory.create(config, run);
      logSummary(run);
      return run;
    } catch (Exception error) {
      Database.rollback(savepoint);
      throw error;
    }
  }

  public static SyntheticDataRun start(SyntheticDataConfig config) {
    assertSafeOrg();
    if (config == null) {
      throw new SyntheticDataException('SyntheticDataConfig is required.');
    }
    config.validate();

    String runKey = String.isBlank(config.runKey)
      ? 'SYNTH-' + Datetime.now().formatGmt('yyyyMMdd-HHmmssSSS')
      : config.runKey.trim();
    if (!runKey.startsWith('SYNTH-')) {
      throw new SyntheticDataException(
        'runKey must start with SYNTH- so cleanup can identify the records.'
      );
    }

    List<Id> ownerIds = SyntheticOwnerResolver.resolveActiveUserIds(
      config.ownerUsernames
    );
    return new SyntheticDataRun(runKey, ownerIds);
  }

  public static void logSummary(SyntheticDataRun run) {
    System.debug(
      LoggingLevel.WARN,
      'Synthetic run ' +
      run.runKey +
      ': ' +
      run.accounts.size() +
      ' accounts, ' +
      run.contacts.size() +
      ' contacts, ' +
      run.leads.size() +
      ' leads, ' +
      run.products.size() +
      ' products, ' +
      run.opportunities.size() +
      ' opportunities, ' +
      run.lineItems.size() +
      ' line items, ' +
      run.tasks.size() +
      ' tasks, and ' +
      run.events.size() +
      ' events.'
    );
  }

  private static void assertSafeOrg() {
    if (Test.isRunningTest()) {
      return;
    }
    Organization orgInfo = [
      SELECT IsSandbox, OrganizationType
      FROM Organization
      LIMIT 1
    ];
    if (
      !orgInfo.IsSandbox && orgInfo.OrganizationType != 'Developer Edition'
    ) {
      throw new SyntheticDataException(
        'Synthetic data generation is allowed only in a sandbox or Developer Edition org.'
      );
    }
  }
}
