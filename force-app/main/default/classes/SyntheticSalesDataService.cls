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

    String randomSuffix = EncodingUtil.convertToHex(Crypto.generateAesKey(128))
      .substring(0, 8);
    String runKey = String.isBlank(config.runKey)
      ? 'SYNTH-' +
        Datetime.now().formatGmt('yyyyMMdd-HHmmssSSS') +
        '-' +
        randomSuffix
      : config.runKey.trim();
    if (
      runKey.length() > 40 || !Pattern.matches('^SYNTH-[A-Za-z0-9-]+$', runKey)
    ) {
      throw new SyntheticDataException(
        'runKey must be 40 characters or fewer and match SYNTH-[A-Za-z0-9-]+.'
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
    if (!orgInfo.IsSandbox && orgInfo.OrganizationType != 'Developer Edition') {
      throw new SyntheticDataException(
        'Synthetic data generation is allowed only in a sandbox or Developer Edition org.'
      );
    }
  }
}
