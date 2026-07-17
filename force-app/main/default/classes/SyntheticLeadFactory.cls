public without sharing class SyntheticLeadFactory {
  public static void create(SyntheticDataConfig config, SyntheticDataRun run) {
    Set<String> activeStatusValues = new Set<String>(
      SyntheticSchemaValueFactory.activePicklistValues(Lead.Status)
    );
    List<String> availableStatuses = new List<String>();
    for (LeadStatus status : [
      SELECT ApiName
      FROM LeadStatus
      WHERE IsConverted = FALSE
      ORDER BY SortOrder
    ]) {
      if (activeStatusValues.contains(status.ApiName)) {
        availableStatuses.add(status.ApiName);
      }
    }
    if (config.leadCount > 0 && availableStatuses.isEmpty()) {
      throw new SyntheticDataException(
        'The org needs at least one active, non-converted Lead status.'
      );
    }

    List<String> industries = SyntheticSchemaValueFactory.preferredActivePicklistValues(
      Lead.Industry,
      config.preferredIndustries
    );
    for (Integer i = 0; i < config.leadCount; i++) {
      String companyName = config.companyNames[
        Math.mod(i, config.companyNames.size())
      ];
      Lead lead = new Lead(
        OwnerId = run.ownerIds[Math.mod(i, run.ownerIds.size())],
        FirstName = 'Prospect',
        LastName = run.runKey + '-Lead-' + String.valueOf(i + 1),
        Company = run.runKey + '-' + companyName + ' Expansion',
        Email = 'synthetic+' +
          run.runKey.toLowerCase() +
          '-lead-' +
          String.valueOf(i + 1) +
          '@example.invalid',
        Status = availableStatuses[Math.mod(i, availableStatuses.size())],
        Description = run.marker()
      );
      if (!industries.isEmpty()) {
        lead.Industry = industries[Math.mod(i, industries.size())];
      }
      SyntheticSchemaValueFactory.populateCustomFields(lead, run.runKey, i + 1);
      run.leads.add(lead);
    }
    insert run.leads;
  }
}
