public without sharing class SyntheticOpportunityFactory {
  public static void create(
    SyntheticDataConfig config,
    SyntheticDataRun run
  ) {
    List<String> openStages = new List<String>();
    List<String> wonStages = new List<String>();
    List<String> lostStages = new List<String>();
    for (OpportunityStage stage : [
      SELECT ApiName, IsClosed, IsWon
      FROM OpportunityStage
      WHERE IsActive = TRUE
      ORDER BY SortOrder
    ]) {
      if (!stage.IsClosed) {
        openStages.add(stage.ApiName);
      } else if (stage.IsWon) {
        wonStages.add(stage.ApiName);
      } else {
        lostStages.add(stage.ApiName);
      }
    }
    if (
      !run.accounts.isEmpty() &&
      config.opportunitiesPerAccount > 0 &&
      openStages.isEmpty()
    ) {
      throw new SyntheticDataException(
        'The org needs at least one active open Opportunity stage.'
      );
    }

    Date today = Date.today();
    Integer salesCycleRange =
      config.maximumSalesCycleDays - config.minimumSalesCycleDays + 1;
    Integer sequence = 0;
    for (Account account : run.accounts) {
      for (
        Integer opportunityIndex = 0;
        opportunityIndex < config.opportunitiesPerAccount;
        opportunityIndex++
      ) {
        Integer outcomeBucket = Math.mod(sequence, 10);
        String stageName;
        Date closeDate;
        if (outcomeBucket < 2 && !wonStages.isEmpty()) {
          stageName = wonStages[Math.mod(sequence, wonStages.size())];
          closeDate = today.addDays(-7 - Math.mod(sequence, 90));
        } else if (outcomeBucket < 4 && !lostStages.isEmpty()) {
          stageName = lostStages[Math.mod(sequence, lostStages.size())];
          closeDate = today.addDays(-7 - Math.mod(sequence, 90));
        } else {
          stageName = openStages[Math.mod(sequence, openStages.size())];
          closeDate = today.addDays(
            config.minimumSalesCycleDays +
            Math.mod(sequence, salesCycleRange)
          );
        }

        String theme = config.opportunityThemes.isEmpty()
          ? 'Manufacturing Program'
          : config.opportunityThemes[
              Math.mod(sequence, config.opportunityThemes.size())
            ];
        Opportunity opportunity = new Opportunity(
          AccountId = account.Id,
          OwnerId = run.ownerIds[Math.mod(sequence, run.ownerIds.size())],
          Name = run.runKey + '-' + theme + '-' + String.valueOf(sequence + 1),
          StageName = stageName,
          CloseDate = closeDate,
          Pricebook2Id = run.standardPricebookId,
          Description = run.marker()
        );
        SyntheticSchemaValueFactory.populateCustomFields(
          opportunity,
          run.runKey,
          sequence + 1
        );
        run.opportunities.add(opportunity);
        sequence++;
      }
    }
    insert run.opportunities;

    Integer quantityRange =
      config.maximumOpportunityQuantity -
      config.minimumOpportunityQuantity +
      1;
    for (Integer i = 0; i < run.opportunities.size(); i++) {
      PricebookEntry entry = run.pricebookEntries[
        Math.mod(i, run.pricebookEntries.size())
      ];
      OpportunityLineItem lineItem = new OpportunityLineItem(
        OpportunityId = run.opportunities[i].Id,
        PricebookEntryId = entry.Id,
        Quantity = config.minimumOpportunityQuantity +
          Math.mod(i, quantityRange),
        UnitPrice = entry.UnitPrice,
        Description = run.marker()
      );
      SyntheticSchemaValueFactory.populateCustomFields(
        lineItem,
        run.runKey,
        i + 1
      );
      run.lineItems.add(lineItem);
    }
    insert run.lineItems;
  }
}
