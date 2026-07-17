public without sharing class SyntheticActivityFactory {
  public static void create(
    SyntheticDataConfig config,
    SyntheticDataRun run
  ) {
    if (
      (config.taskCount > 0 || config.eventCount > 0) &&
      run.accounts.isEmpty() &&
      run.contacts.isEmpty() &&
      run.leads.isEmpty()
    ) {
      throw new SyntheticDataException(
        'Activities require at least one generated Account, Contact, or Lead.'
      );
    }

    createTasks(config, run);
    createEvents(config, run);
  }

  private static void createTasks(
    SyntheticDataConfig config,
    SyntheticDataRun run
  ) {
    List<String> subjects = SyntheticSchemaValueFactory.preferredActivePicklistValues(
      Task.Subject,
      config.preferredTaskSubjects
    );
    if (subjects.isEmpty()) {
      subjects.add('Manufacturing Follow-up');
    }
    List<String> statuses = SyntheticSchemaValueFactory.activePicklistValues(
      Task.Status
    );
    List<String> priorities = SyntheticSchemaValueFactory.activePicklistValues(
      Task.Priority
    );
    if (
      config.taskCount > 0 && (statuses.isEmpty() || priorities.isEmpty())
    ) {
      throw new SyntheticDataException(
        'The org needs active Task status and priority values.'
      );
    }

    for (Integer i = 0; i < config.taskCount; i++) {
      Task task = new Task(
        OwnerId = run.ownerIds[Math.mod(i, run.ownerIds.size())],
        Subject = subjects[Math.mod(i, subjects.size())],
        Status = statuses[Math.mod(i, statuses.size())],
        Priority = priorities[Math.mod(i, priorities.size())],
        ActivityDate = Date.today().addDays(-14 + Math.mod(i, 45)),
        Description = run.marker()
      );
      relateActivity(task, run, i);
      SyntheticSchemaValueFactory.populateCustomFields(
        task,
        run.runKey,
        i + 1
      );
      run.tasks.add(task);
    }
    insert run.tasks;
  }

  private static void createEvents(
    SyntheticDataConfig config,
    SyntheticDataRun run
  ) {
    List<String> subjects = SyntheticSchemaValueFactory.preferredActivePicklistValues(
      Event.Subject,
      config.preferredEventSubjects
    );
    if (subjects.isEmpty()) {
      subjects.add('Manufacturing Site Visit');
    }

    for (Integer i = 0; i < config.eventCount; i++) {
      Datetime startTime = Datetime.now()
        .addDays(-10 + Math.mod(i, 30))
        .addHours(9 + Math.mod(i, 8));
      Event calendarEvent = new Event(
        OwnerId = run.ownerIds[Math.mod(i, run.ownerIds.size())],
        Subject = subjects[Math.mod(i, subjects.size())],
        StartDateTime = startTime,
        EndDateTime = startTime.addMinutes(30 + (Math.mod(i, 3) * 30)),
        Description = run.marker()
      );
      relateActivity(calendarEvent, run, i);
      SyntheticSchemaValueFactory.populateCustomFields(
        calendarEvent,
        run.runKey,
        i + 1
      );
      run.events.add(calendarEvent);
    }
    insert run.events;
  }

  private static void relateActivity(
    SObject activity,
    SyntheticDataRun run,
    Integer sequence
  ) {
    Boolean useLead = !run.leads.isEmpty() &&
      (run.contacts.isEmpty() || Math.mod(sequence, 2) == 1);
    if (useLead) {
      activity.put(
        'WhoId',
        run.leads[Math.mod(sequence, run.leads.size())].Id
      );
      return;
    }
    if (!run.contacts.isEmpty()) {
      activity.put(
        'WhoId',
        run.contacts[Math.mod(sequence, run.contacts.size())].Id
      );
      if (!run.opportunities.isEmpty()) {
        activity.put(
          'WhatId',
          run.opportunities[Math.mod(sequence, run.opportunities.size())].Id
        );
      }
      return;
    }
    activity.put(
      'WhatId',
      run.accounts[Math.mod(sequence, run.accounts.size())].Id
    );
  }
}
