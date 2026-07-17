@IsTest
private class SalesManagerMutationActionTest {
  @TestSetup
  static void createData() {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String uniqueValue = String.valueOf(DateTime.now().getTime());
    User manager = new User(
      Alias = 'mutmgr',
      Email = 'mutation.manager.' + uniqueValue + '@example.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Mutation Manager',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'mutation.manager.' + uniqueValue + '@example.test'
    );
    insert manager;
    insert new User(
      Alias = 'mutrep',
      Email = 'mutation.report.' + uniqueValue + '@example.test',
      EmailEncodingKey = 'UTF-8',
      FirstName = 'Taylor',
      LastName = 'Mutation Seller',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ManagerId = manager.Id,
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'mutation.report.' + uniqueValue + '@example.test'
    );

    System.runAs(manager) {
      insert new Account(
        Name = 'Mutation Test Account',
        Industry = 'Technology',
        OwnerId = manager.Id
      );
    }
  }

  @IsTest
  static void updatesAllowlistedFieldsInUserMode() {
    User manager = [
      SELECT Id
      FROM User
      WHERE LastName = 'Mutation Manager'
      LIMIT 1
    ];
    Account account = [
      SELECT Id
      FROM Account
      WHERE Name = 'Mutation Test Account'
      LIMIT 1
    ];
    System.runAs(manager) {
      SalesManagerMutationAction.Request request = new SalesManagerMutationAction.Request();
      request.operation = 'UPDATE_RECORD';
      request.recordId = account.Id;
      request.updatesJson = '{"Name":"Updated by Sales Manager Agent","AnnualRevenue":1250000}';

      Test.startTest();
      SalesManagerMutationAction.Response response = SalesManagerMutationAction.changeRecords(
        new List<SalesManagerMutationAction.Request>{ request }
      )[0];
      Test.stopTest();

      System.assertEquals(true, response.success, response.message);
      System.assertEquals(String.valueOf(account.Id), response.recordId);
      Account updatedAccount = [
        SELECT Name, AnnualRevenue
        FROM Account
        WHERE Id = :account.Id
      ];
      System.assertEquals(
        'Updated by Sales Manager Agent',
        updatedAccount.Name
      );
      System.assertEquals(1250000, updatedAccount.AnnualRevenue);
    }
  }

  @IsTest
  static void createsTaskForDirectReport() {
    User manager = [
      SELECT Id
      FROM User
      WHERE LastName = 'Mutation Manager'
      LIMIT 1
    ];
    User report = [
      SELECT Id, Name
      FROM User
      WHERE LastName = 'Mutation Seller'
      LIMIT 1
    ];
    Account account = [
      SELECT Id
      FROM Account
      WHERE Name = 'Mutation Test Account'
      LIMIT 1
    ];
    System.runAs(manager) {
      SalesManagerMutationAction.Request request = new SalesManagerMutationAction.Request();
      request.operation = 'CREATE_TASK';
      request.assigneeName = 'Taylor';
      request.subject = 'Follow up on agent test';
      request.dueDate = String.valueOf(Date.today().addDays(2));
      request.relatedRecordId = account.Id;

      Test.startTest();
      SalesManagerMutationAction.Response response = SalesManagerMutationAction.changeRecords(
        new List<SalesManagerMutationAction.Request>{ request }
      )[0];
      Test.stopTest();

      System.assertEquals(true, response.success, response.message);
      Id createdTaskId = Id.valueOf(response.recordId);
      Task createdTask = [
        SELECT Subject, ActivityDate, OwnerId, WhatId
        FROM Task
        WHERE Id = :createdTaskId
      ];
      System.assertEquals('Follow up on agent test', createdTask.Subject);
      System.assertEquals(Date.today().addDays(2), createdTask.ActivityDate);
      System.assertEquals(report.Id, createdTask.OwnerId);
      System.assertEquals(account.Id, createdTask.WhatId);
    }
  }

  @IsTest
  static void reassignsExistingTaskToDirectReport() {
    User manager = [
      SELECT Id
      FROM User
      WHERE LastName = 'Mutation Manager'
      LIMIT 1
    ];
    User report = [
      SELECT Id
      FROM User
      WHERE LastName = 'Mutation Seller'
      LIMIT 1
    ];
    Task taskToAssign;
    System.runAs(manager) {
      taskToAssign = new Task(
        Subject = 'Task to reassign',
        OwnerId = manager.Id
      );
      insert taskToAssign;

      SalesManagerMutationAction.Request request = new SalesManagerMutationAction.Request();
      request.operation = 'ASSIGN_TASK';
      request.recordId = taskToAssign.Id;
      request.assigneeName = 'Taylor Mutation Seller';

      Test.startTest();
      SalesManagerMutationAction.Response response = SalesManagerMutationAction.changeRecords(
        new List<SalesManagerMutationAction.Request>{ request }
      )[0];
      Test.stopTest();

      System.assertEquals(true, response.success, response.message);
      Task assignedTask = [
        SELECT OwnerId
        FROM Task
        WHERE Id = :taskToAssign.Id
      ];
      System.assertEquals(report.Id, assignedTask.OwnerId);
    }
  }

  @IsTest
  static void rejectsDisallowedFieldAndOutsideAssignee() {
    User manager = [
      SELECT Id
      FROM User
      WHERE LastName = 'Mutation Manager'
      LIMIT 1
    ];
    Account account = [
      SELECT Id
      FROM Account
      WHERE Name = 'Mutation Test Account'
      LIMIT 1
    ];
    System.runAs(manager) {
      SalesManagerMutationAction.Request disallowedUpdate = new SalesManagerMutationAction.Request();
      disallowedUpdate.operation = 'UPDATE_RECORD';
      disallowedUpdate.recordId = account.Id;
      disallowedUpdate.updatesJson = '{"OwnerId":"' + manager.Id + '"}';

      SalesManagerMutationAction.Request unknownAssignee = new SalesManagerMutationAction.Request();
      unknownAssignee.operation = 'CREATE_TASK';
      unknownAssignee.subject = 'Should not be created';
      unknownAssignee.assigneeName = 'Not A Team Member';

      Test.startTest();
      List<SalesManagerMutationAction.Response> responses = SalesManagerMutationAction.changeRecords(
        new List<SalesManagerMutationAction.Request>{
          disallowedUpdate,
          unknownAssignee
        }
      );
      Test.stopTest();

      System.assertEquals(false, responses[0].success);
      System.assert(responses[0].message.contains('not allowed'));
      System.assertEquals(false, responses[1].success);
      System.assert(responses[1].message.contains('No active direct report'));
    }
  }
}
