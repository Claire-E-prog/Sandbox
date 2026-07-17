public without sharing class SyntheticProductFactory {
  public static void create(SyntheticDataConfig config, SyntheticDataRun run) {
    if (config.products == null || config.products.isEmpty()) {
      throw new SyntheticDataException(
        'Product generation requires at least one product definition.'
      );
    }
    Pricebook2 standardPricebook;
    if (Test.isRunningTest()) {
      Id standardPricebookId = Test.getStandardPricebookId();
      standardPricebook = [
        SELECT Id, IsActive
        FROM Pricebook2
        WHERE Id = :standardPricebookId
      ];
    } else {
      standardPricebook = [
        SELECT Id, IsActive
        FROM Pricebook2
        WHERE IsStandard = TRUE
        LIMIT 1
      ];
    }
    if (!standardPricebook.IsActive) {
      throw new SyntheticDataException(
        'Activate the standard price book before generating products.'
      );
    }
    run.standardPricebookId = standardPricebook.Id;

    for (Integer i = 0; i < config.products.size(); i++) {
      SyntheticDataConfig.ProductDefinition definition = config.products[i];
      Product2 product = new Product2(
        Name = run.runKey + '-' + definition.name,
        ProductCode = run.runKey + '-' + definition.productCode,
        IsActive = true,
        Description = run.marker()
      );
      SyntheticSchemaValueFactory.populateCustomFields(
        product,
        run.runKey,
        i + 1
      );
      run.products.add(product);
    }
    insert run.products;

    for (Integer i = 0; i < run.products.size(); i++) {
      PricebookEntry entry = new PricebookEntry(
        Pricebook2Id = run.standardPricebookId,
        Product2Id = run.products[i].Id,
        UnitPrice = config.products[i].unitPrice,
        IsActive = true
      );
      SyntheticSchemaValueFactory.populateCustomFields(
        entry,
        run.runKey,
        i + 1
      );
      run.pricebookEntries.add(entry);
    }
    insert run.pricebookEntries;
  }
}
