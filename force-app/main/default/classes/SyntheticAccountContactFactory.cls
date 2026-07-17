public without sharing class SyntheticAccountContactFactory {
  public static void create(
    SyntheticDataConfig config,
    SyntheticDataRun run
  ) {
    List<String> industries = SyntheticSchemaValueFactory.preferredActivePicklistValues(
      Account.Industry,
      config.preferredIndustries
    );

    for (Integer i = 0; i < config.accountCount; i++) {
      String baseCompanyName = config.companyNames[
        Math.mod(i, config.companyNames.size())
      ];
      Account account = new Account(
        Name = run.runKey +
          '-' +
          baseCompanyName +
          (i >= config.companyNames.size()
            ? ' Plant ' + String.valueOf(i + 1)
            : ''),
        OwnerId = run.ownerIds[Math.mod(i, run.ownerIds.size())],
        BillingCity = config.cities.isEmpty()
          ? null
          : config.cities[Math.mod(i, config.cities.size())],
        BillingCountry = 'United States',
        NumberOfEmployees = config.minimumEmployees + (i * config.employeeStep),
        AnnualRevenue = config.minimumAnnualRevenue +
          (i * config.annualRevenueStep),
        Description = run.marker()
      );
      if (!industries.isEmpty()) {
        account.Industry = industries[Math.mod(i, industries.size())];
      }
      SyntheticSchemaValueFactory.populateCustomFields(
        account,
        run.runKey,
        i + 1
      );
      run.accounts.add(account);
    }
    insert run.accounts;

    Integer sequence = 0;
    for (Account account : run.accounts) {
      for (
        Integer contactIndex = 0;
        contactIndex < config.contactsPerAccount;
        contactIndex++
      ) {
        sequence++;
        Contact contact = new Contact(
          AccountId = account.Id,
          OwnerId = run.ownerIds[
            Math.mod(sequence - 1, run.ownerIds.size())
          ],
          FirstName = 'Manufacturing',
          LastName = run.runKey + '-Contact-' + String.valueOf(sequence),
          Email = 'synthetic+' +
            run.runKey.toLowerCase() +
            '-contact-' +
            String.valueOf(sequence) +
            '@example.invalid',
          Title = config.contactTitles.isEmpty()
            ? 'Operations Manager'
            : config.contactTitles[
                Math.mod(contactIndex, config.contactTitles.size())
              ],
          Description = run.marker()
        );
        SyntheticSchemaValueFactory.populateCustomFields(
          contact,
          run.runKey,
          sequence
        );
        run.contacts.add(contact);
      }
    }
    insert run.contacts;
  }
}
