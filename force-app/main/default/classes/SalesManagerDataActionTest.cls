@IsTest
private class SalesManagerDataActionTest {
  @TestSetup
  static void createData() {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    OpportunityStage openStage = [
      SELECT MasterLabel
      FROM OpportunityStage
      WHERE IsActive = TRUE AND IsClosed = FALSE
      LIMIT 1
    ];
    TaskStatus defaultTaskStatus = [
      SELECT MasterLabel
      FROM TaskStatus
      WHERE IsDefault = TRUE
      LIMIT 1
    ];
    TaskPriority defaultTaskPriority = [
      SELECT MasterLabel
      FROM TaskPriority
      WHERE IsDefault = TRUE
      LIMIT 1
    ];
    String uniqueValue = String.valueOf(DateTime.now().getTime());

    User manager = new User(
      Alias = 'mgrtest',
      Email = 'manager.' + uniqueValue + '@example.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Manager',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'manager.' + uniqueValue + '@example.test'
    );
    insert manager;

    User report = new User(
      Alias = 'reptest',
      Email = 'report.' + uniqueValue + '@example.test',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Seller',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ManagerId = manager.Id,
      ProfileId = standardProfile.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = 'report.' + uniqueValue + '@example.test'
    );
    insert report;

    System.runAs(manager) {
      Account account = new Account(
        Name = 'Acme Agent Test',
        Industry = 'Technology',
        OwnerId = manager.Id
      );
      insert account;
      insert new Opportunity(
        Name = 'Acme Renewal',
        AccountId = account.Id,
        Amount = 50000,
        CloseDate = Date.today().addDays(7),
        StageName = openStage.MasterLabel,
        OwnerId = manager.Id
      );
      insert new Task(
        Subject = 'Call Acme buyer',
        ActivityDate = Date.today(),
        Status = defaultTaskStatus.MasterLabel,
        Priority = defaultTaskPriority.MasterLabel,
        WhatId = account.Id,
        OwnerId = manager.Id
      );
    }
  }

  @IsTest
  static void returnsManagersAccessibleAccounts() {
    User manager = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
    System.runAs(manager) {
      SalesManagerDataAction.Request request = new SalesManagerDataAction.Request();
      request.recordType = 'ACCOUNT';
      request.ownerScope = 'MINE';
      request.searchTerm = 'Acme';
      request.maxResults = 5;

      Test.startTest();
      SalesManagerDataAction.Response response = SalesManagerDataAction.getRecords(
        new List<SalesManagerDataAction.Request>{ request }
      )[0];
      Test.stopTest();

      System.assertEquals(true, response.success, response.summary);
      System.assertEquals(1, response.returnedCount);
      System.assert(response.recordsJson.contains('Acme Agent Test'));
      System.assertEquals(false, response.hasMore);
    }
  }

  @IsTest
  static void supportsOpportunityAndTaskFilters() {
    User manager = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
    System.runAs(manager) {
      Opportunity opportunity = [
        SELECT StageName
        FROM Opportunity
        WHERE Name = 'Acme Renewal'
        LIMIT 1
      ];
      SalesManagerDataAction.Request opportunityRequest = new SalesManagerDataAction.Request();
      opportunityRequest.recordType = 'OPPORTUNITY';
      opportunityRequest.ownerScope = 'TEAM';
      opportunityRequest.statusFilter = opportunity.StageName;
      opportunityRequest.dateWindow = 'NEXT_7_DAYS';

      SalesManagerDataAction.Request taskRequest = new SalesManagerDataAction.Request();
      taskRequest.recordType = 'TASK';
      taskRequest.ownerScope = 'MINE';
      taskRequest.dateWindow = 'TODAY';

      Test.startTest();
      List<SalesManagerDataAction.Response> responses = SalesManagerDataAction.getRecords(
        new List<SalesManagerDataAction.Request>{
          opportunityRequest,
          taskRequest
        }
      );
      Test.stopTest();

      System.assertEquals(true, responses[0].success, responses[0].summary);
      System.assertEquals(1, responses[0].returnedCount);
      System.assert(responses[0].recordsJson.contains('Acme Renewal'));
      System.assertEquals(true, responses[1].success, responses[1].summary);
      System.assertEquals(1, responses[1].returnedCount);
    }
  }

  @IsTest
  static void summarizesPipelineWithDatabaseAggregates() {
    User manager = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
    System.runAs(manager) {
      Opportunity opportunity = [
        SELECT StageName
        FROM Opportunity
        WHERE Name = 'Acme Renewal'
        LIMIT 1
      ];
      SalesManagerDataAction.Request request = new SalesManagerDataAction.Request();
      request.recordType = 'OPPORTUNITY';
      request.queryMode = 'SUMMARY';
      request.ownerScope = 'MINE';
      request.statusFilter = 'OPEN';
      request.dateWindow = 'NEXT_30_DAYS';

      Test.startTest();
      SalesManagerDataAction.Response response = SalesManagerDataAction.getRecords(
        new List<SalesManagerDataAction.Request>{ request }
      )[0];
      Test.stopTest();

      System.assertEquals(true, response.success, response.summary);
      System.assertEquals(1, response.returnedCount);
      System.assert(response.recordsJson.contains(opportunity.StageName));
      System.assert(response.recordsJson.contains('50000'));
      System.assert(response.recordsJson.contains('totalAmount'));
    }
  }

  @IsTest
  static void resolvesNamedDirectReportWithoutBypassingSharing() {
    User manager = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
    System.runAs(manager) {
      SalesManagerDataAction.Request request = new SalesManagerDataAction.Request();
      request.recordType = 'LEAD';
      request.ownerName = 'Seller';

      Test.startTest();
      SalesManagerDataAction.Response response = SalesManagerDataAction.getRecords(
        new List<SalesManagerDataAction.Request>{ request }
      )[0];
      Test.stopTest();

      System.assertEquals(true, response.success, response.summary);
      System.assertEquals(0, response.returnedCount);
      System.assertEquals('[]', response.recordsJson);
    }
  }

  @IsTest
  static void returnsSafeValidationErrors() {
    User manager = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
    System.runAs(manager) {
      SalesManagerDataAction.Request invalidType = new SalesManagerDataAction.Request();
      invalidType.recordType = 'CONTACT';

      SalesManagerDataAction.Request invalidFilter = new SalesManagerDataAction.Request();
      invalidFilter.recordType = 'ACCOUNT';
      invalidFilter.statusFilter = 'Active';

      Test.startTest();
      List<SalesManagerDataAction.Response> responses = SalesManagerDataAction.getRecords(
        new List<SalesManagerDataAction.Request>{ invalidType, invalidFilter }
      );
      Test.stopTest();

      System.assertEquals(false, responses[0].success);
      System.assert(responses[0].summary.contains('Record type must be'));
      System.assertEquals(false, responses[1].success);
      System.assert(responses[1].summary.contains('Status filtering'));
    }
  }

  @IsTest
  static void capsResultLimitAndDetectsAdditionalMatches() {
    User manager = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];
    System.runAs(manager) {
      List<Account> accounts = new List<Account>();
      for (Integer index = 0; index < 26; index++) {
        accounts.add(
          new Account(Name = 'Limit Test ' + index, OwnerId = manager.Id)
        );
      }
      insert accounts;

      SalesManagerDataAction.Request request = new SalesManagerDataAction.Request();
      request.recordType = 'ACCOUNT';
      request.ownerScope = 'MINE';
      request.searchTerm = 'Limit Test';
      request.maxResults = 100;

      Test.startTest();
      SalesManagerDataAction.Response response = SalesManagerDataAction.getRecords(
        new List<SalesManagerDataAction.Request>{ request }
      )[0];
      Test.stopTest();

      System.assertEquals(true, response.success, response.summary);
      System.assertEquals(25, response.returnedCount);
      System.assertEquals(true, response.hasMore);
    }
  }
}
