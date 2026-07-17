@IsTest
private class SimpleAccountLookupActionTest {
  @IsTest
  static void findsAnAccountByName() {
    insert new Account(
      Name = 'Simple Agent Acme',
      Industry = 'Technology',
      Phone = '555-0100'
    );

    SimpleAccountLookupAction.Request request =
      new SimpleAccountLookupAction.Request();
    request.searchTerm = 'Agent Acme';
    request.maxResults = 3;

    Test.startTest();
    SimpleAccountLookupAction.Response response =
      SimpleAccountLookupAction.getAccounts(
        new List<SimpleAccountLookupAction.Request>{ request }
      )[0];
    Test.stopTest();

    System.assertEquals(true, response.success, response.message);
    System.assertEquals('Found 1 accessible Account.', response.message);
    System.assert(response.accountsJson.contains('Simple Agent Acme'));
    System.assert(response.accountsJson.contains('Technology'));
  }

  @IsTest
  static void capsTheMaximumNumberOfResults() {
    List<Account> accounts = new List<Account>();
    for (Integer index = 0; index < 11; index++) {
      accounts.add(new Account(Name = 'Simple Limit Test ' + index));
    }
    insert accounts;

    SimpleAccountLookupAction.Request request =
      new SimpleAccountLookupAction.Request();
    request.searchTerm = 'Simple Limit Test';
    request.maxResults = 50;

    Test.startTest();
    SimpleAccountLookupAction.Response response =
      SimpleAccountLookupAction.getAccounts(
        new List<SimpleAccountLookupAction.Request>{ request }
      )[0];
    Test.stopTest();

    List<Object> returnedAccounts = (List<Object>) JSON.deserializeUntyped(
      response.accountsJson
    );
    System.assertEquals(true, response.success, response.message);
    System.assertEquals(10, returnedAccounts.size());
  }
}
