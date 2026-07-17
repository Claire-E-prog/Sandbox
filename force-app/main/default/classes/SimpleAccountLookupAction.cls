/**
 * One read-only Agentforce action that returns Accounts owned by the current
 * user. Sharing, object permissions, and field permissions are enforced.
 */
public inherited sharing class SimpleAccountLookupAction {
  private static final Integer DEFAULT_LIMIT = 5;
  private static final Integer MAX_LIMIT = 10;

  @InvocableMethod(
    label='Find My Accounts'
    description='Returns accessible Accounts owned by the logged-in user, optionally filtered by Account name.'
  )
  public static List<Response> getAccounts(List<Request> requests) {
    List<Response> responses = new List<Response>();
    if (requests == null) {
      return responses;
    }

    for (Request request : requests) {
      responses.add(findAccounts(request));
    }
    return responses;
  }

  private static Response findAccounts(Request request) {
    Response response = new Response();
    if (request == null) {
      response.success = false;
      response.message = 'An Account lookup request is required.';
      response.accountsJson = '[]';
      return response;
    }

    Integer resultLimit = request.maxResults == null
      ? DEFAULT_LIMIT
      : Math.max(1, Math.min(MAX_LIMIT, request.maxResults));
    Id currentUserId = UserInfo.getUserId();

    try {
      List<Account> accounts;
      if (String.isBlank(request.searchTerm)) {
        accounts = [
          SELECT Id, Name, Industry, Phone, Owner.Name
          FROM Account
          WHERE OwnerId = :currentUserId
          WITH USER_MODE
          ORDER BY Name
          LIMIT :resultLimit
        ];
      } else {
        String namePattern = '%' + request.searchTerm.trim() + '%';
        accounts = [
          SELECT Id, Name, Industry, Phone, Owner.Name
          FROM Account
          WHERE OwnerId = :currentUserId AND Name LIKE :namePattern
          WITH USER_MODE
          ORDER BY Name
          LIMIT :resultLimit
        ];
      }

      response.success = true;
      response.message =
        'Found ' +
        accounts.size() +
        (accounts.size() == 1 ? ' accessible Account.' : ' accessible Accounts.');
      response.accountsJson = JSON.serialize(accounts);
    } catch (QueryException exceptionValue) {
      response.success = false;
      response.message =
        'Salesforce denied the Account query. Check the user\'s Account and field permissions.';
      response.accountsJson = '[]';
    }
    return response;
  }

  public class Request {
    @InvocableVariable(
      label='Account Name'
      description='Optional text that should appear in the Account name.'
    )
    public String searchTerm;

    @InvocableVariable(
      label='Maximum Results'
      description='Maximum Accounts to return, from 1 through 10. Defaults to 5.'
    )
    public Integer maxResults;
  }

  public class Response {
    @InvocableVariable(
      label='Success'
      description='True when the Account lookup succeeded.'
    )
    public Boolean success;

    @InvocableVariable(
      label='Message'
      description='A short result summary or safe error message.'
    )
    public String message;

    @InvocableVariable(
      label='Accounts JSON'
      description='JSON containing the accessible Accounts returned by the lookup.'
    )
    public String accountsJson;
  }
}
