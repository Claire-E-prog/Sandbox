/**
 * Read-only Agentforce action for a sales manager and their direct reports.
 *
 * The class intentionally uses inherited sharing and USER_MODE queries. A manager
 * relationship identifies the requested owners; it does not bypass record sharing,
 * object permissions, or field-level security.
 */
public inherited sharing class SalesManagerDataAction {
  private static final Integer DEFAULT_LIMIT = 10;
  private static final Integer MAX_LIMIT = 25;
  private static final Integer MAX_SUMMARY_GROUPS = 200;
  private static final Integer MAX_REQUESTS = 50;
  private static final Set<String> RECORD_TYPES = new Set<String>{
    'ACCOUNT',
    'OPPORTUNITY',
    'LEAD',
    'TASK',
    'EVENT'
  };
  private static final Set<String> OWNER_SCOPES = new Set<String>{
    'MINE',
    'DIRECT_REPORTS',
    'TEAM'
  };
  private static final Set<String> DATE_WINDOWS = new Set<String>{
    'ALL',
    'OVERDUE',
    'TODAY',
    'NEXT_7_DAYS',
    'NEXT_30_DAYS'
  };

  @InvocableMethod(
    label='Get Sales Manager Records'
    description='Returns accessible accounts, opportunities, leads, tasks, or events owned by the current manager or an active direct report. Use this action for sales data questions.'
  )
  public static List<Response> getRecords(List<Request> requests) {
    if (requests == null || requests.isEmpty()) {
      return new List<Response>();
    }
    if (requests.size() > MAX_REQUESTS) {
      throw new SalesManagerDataException(
        'A maximum of 50 requests is supported per invocation.'
      );
    }

    TeamContext team = loadTeamContext();
    List<Response> responses = new List<Response>();
    for (Request request : requests) {
      try {
        responses.add(executeRequest(request, team));
      } catch (SalesManagerDataException exceptionValue) {
        responses.add(failureResponse(exceptionValue.getMessage()));
      } catch (QueryException exceptionValue) {
        responses.add(
          failureResponse(
            'Salesforce denied the query. Check the user\'s object and field permissions.'
          )
        );
      } catch (Exception exceptionValue) {
        responses.add(
          failureResponse(
            'An unexpected error occurred while retrieving sales records.'
          )
        );
      }
    }
    return responses;
  }

  private static Response executeRequest(Request request, TeamContext team) {
    if (request == null) {
      throw new SalesManagerDataException('The request is required.');
    }

    String recordType = normalize(request.recordType);
    if (!RECORD_TYPES.contains(recordType)) {
      throw new SalesManagerDataException(
        'Record type must be ACCOUNT, OPPORTUNITY, LEAD, TASK, or EVENT.'
      );
    }

    Set<Id> ownerIds = resolveOwnerIds(request, team);
    String queryMode = String.isBlank(request.queryMode)
      ? 'LIST'
      : normalize(request.queryMode);
    if (queryMode != 'LIST' && queryMode != 'SUMMARY') {
      throw new SalesManagerDataException(
        'Query mode must be LIST or SUMMARY.'
      );
    }

    Integer resultLimit = request.maxResults == null
      ? DEFAULT_LIMIT
      : Math.max(1, Math.min(MAX_LIMIT, request.maxResults));
    Map<String, Object> binds = new Map<String, Object>{
      'ownerIds' => ownerIds
    };
    Integer effectiveLimit = queryMode == 'SUMMARY'
      ? MAX_SUMMARY_GROUPS
      : resultLimit;
    String query = queryMode == 'SUMMARY'
      ? buildSummaryQuery(recordType, request, binds, effectiveLimit + 1)
      : buildListQuery(recordType, request, binds, effectiveLimit + 1);

    List<SObject> queriedRecords = Database.queryWithBinds(
      query,
      binds,
      AccessLevel.USER_MODE
    );
    Boolean hasMore = queriedRecords.size() > effectiveLimit;
    if (hasMore) {
      queriedRecords.remove(queriedRecords.size() - 1);
    }

    Response response = new Response();
    response.success = true;
    response.returnedCount = queriedRecords.size();
    response.hasMore = hasMore;
    response.recordsJson = JSON.serialize(queriedRecords);
    response.summary = buildResponseSummary(
      recordType,
      queryMode,
      queriedRecords.size(),
      hasMore
    );
    return response;
  }

  private static Set<Id> resolveOwnerIds(Request request, TeamContext team) {
    if (!String.isBlank(request.ownerName)) {
      String requestedName = request.ownerName.trim().toLowerCase();
      Set<Id> matches = new Set<Id>();
      for (Id userId : team.namesById.keySet()) {
        String candidate = team.namesById.get(userId);
        if (
          candidate != null && candidate.toLowerCase().contains(requestedName)
        ) {
          matches.add(userId);
        }
      }
      if (matches.isEmpty()) {
        throw new SalesManagerDataException(
          'No active direct report or current manager matched owner name "' +
            request.ownerName +
            '".'
        );
      }
      if (matches.size() > 1) {
        throw new SalesManagerDataException(
          'Owner name "' +
            request.ownerName +
            '" matched multiple team members. Ask the user for a more specific name.'
        );
      }
      return matches;
    }

    String scope = String.isBlank(request.ownerScope)
      ? 'TEAM'
      : normalize(request.ownerScope);
    if (!OWNER_SCOPES.contains(scope)) {
      throw new SalesManagerDataException(
        'Owner scope must be MINE, DIRECT_REPORTS, or TEAM.'
      );
    }
    if (scope == 'MINE') {
      return new Set<Id>{ team.managerId };
    }
    if (scope == 'DIRECT_REPORTS') {
      if (team.directReportIds.isEmpty()) {
        throw new SalesManagerDataException(
          'The current user has no active direct reports.'
        );
      }
      return new Set<Id>(team.directReportIds);
    }

    Set<Id> teamIds = new Set<Id>(team.directReportIds);
    teamIds.add(team.managerId);
    return teamIds;
  }

  private static String buildListQuery(
    String recordType,
    Request request,
    Map<String, Object> binds,
    Integer queryLimit
  ) {
    String selectClause;
    String orderClause;
    if (recordType == 'ACCOUNT') {
      selectClause =
        'SELECT Id, Name, Type, Industry, AnnualRevenue, LastActivityDate, ' +
        'OwnerId, Owner.Name FROM Account';
      orderClause = ' ORDER BY LastActivityDate DESC NULLS LAST, Name ASC';
    } else if (recordType == 'OPPORTUNITY') {
      selectClause =
        'SELECT Id, Name, AccountId, Account.Name, StageName, Amount, Probability, ' +
        'CloseDate, NextStep, OwnerId, Owner.Name FROM Opportunity';
      orderClause = ' ORDER BY CloseDate ASC, Amount DESC NULLS LAST';
    } else if (recordType == 'LEAD') {
      selectClause =
        'SELECT Id, Name, Company, Status, Rating, Email, Phone, ' +
        'OwnerId, Owner.Name FROM Lead';
      orderClause = ' ORDER BY LastModifiedDate DESC';
    } else if (recordType == 'TASK') {
      selectClause =
        'SELECT Id, Subject, Status, Priority, ActivityDate, WhatId, WhoId, ' +
        'OwnerId, Owner.Name FROM Task';
      orderClause = ' ORDER BY ActivityDate ASC NULLS LAST, Priority DESC';
    } else {
      selectClause =
        'SELECT Id, Subject, StartDateTime, EndDateTime, ActivityDate, Location, ' +
        'WhatId, WhoId, OwnerId, Owner.Name FROM Event';
      orderClause = ' ORDER BY StartDateTime ASC';
    }

    List<String> conditions = new List<String>{ 'OwnerId IN :ownerIds' };
    addSearchCondition(recordType, request.searchTerm, conditions, binds);
    addStatusCondition(recordType, request.statusFilter, conditions, binds);
    addDateCondition(recordType, request.dateWindow, conditions);

    return selectClause +
      ' WHERE ' +
      String.join(conditions, ' AND ') +
      orderClause +
      ' LIMIT ' +
      queryLimit;
  }

  private static String buildSummaryQuery(
    String recordType,
    Request request,
    Map<String, Object> binds,
    Integer queryLimit
  ) {
    String selectClause;
    String groupClause;
    if (recordType == 'ACCOUNT') {
      selectClause =
        'SELECT OwnerId ownerId, Owner.Name ownerName, Type status, ' +
        'COUNT(Id) recordCount FROM Account';
      groupClause = ' GROUP BY OwnerId, Owner.Name, Type';
    } else if (recordType == 'OPPORTUNITY') {
      selectClause =
        'SELECT OwnerId ownerId, Owner.Name ownerName, StageName status, ' +
        'COUNT(Id) recordCount, SUM(Amount) totalAmount FROM Opportunity';
      groupClause = ' GROUP BY OwnerId, Owner.Name, StageName';
    } else if (recordType == 'LEAD') {
      selectClause =
        'SELECT OwnerId ownerId, Owner.Name ownerName, Status status, ' +
        'COUNT(Id) recordCount FROM Lead';
      groupClause = ' GROUP BY OwnerId, Owner.Name, Status';
    } else if (recordType == 'TASK') {
      selectClause =
        'SELECT OwnerId ownerId, Owner.Name ownerName, Status status, ' +
        'COUNT(Id) recordCount FROM Task';
      groupClause = ' GROUP BY OwnerId, Owner.Name, Status';
    } else {
      selectClause =
        'SELECT OwnerId ownerId, Owner.Name ownerName, ' +
        'COUNT(Id) recordCount FROM Event';
      groupClause = ' GROUP BY OwnerId, Owner.Name';
    }

    List<String> conditions = new List<String>{ 'OwnerId IN :ownerIds' };
    addSearchCondition(recordType, request.searchTerm, conditions, binds);
    addStatusCondition(recordType, request.statusFilter, conditions, binds);
    addDateCondition(recordType, request.dateWindow, conditions);

    return selectClause +
      ' WHERE ' +
      String.join(conditions, ' AND ') +
      groupClause +
      ' ORDER BY COUNT(Id) DESC LIMIT ' +
      queryLimit;
  }

  private static void addSearchCondition(
    String recordType,
    String searchTerm,
    List<String> conditions,
    Map<String, Object> binds
  ) {
    if (String.isBlank(searchTerm)) {
      return;
    }
    binds.put('searchPattern', '%' + searchTerm.trim() + '%');
    if (recordType == 'LEAD') {
      conditions.add(
        '(Name LIKE :searchPattern OR Company LIKE :searchPattern)'
      );
    } else if (recordType == 'TASK' || recordType == 'EVENT') {
      conditions.add('Subject LIKE :searchPattern');
    } else {
      conditions.add('Name LIKE :searchPattern');
    }
  }

  private static void addStatusCondition(
    String recordType,
    String statusFilter,
    List<String> conditions,
    Map<String, Object> binds
  ) {
    if (String.isBlank(statusFilter)) {
      return;
    }
    String normalizedStatus = normalize(statusFilter);
    if (recordType == 'OPPORTUNITY') {
      if (normalizedStatus == 'OPEN') {
        conditions.add('IsClosed = FALSE');
      } else if (normalizedStatus == 'CLOSED') {
        conditions.add('IsClosed = TRUE');
      } else if (normalizedStatus == 'WON') {
        conditions.add('IsWon = TRUE');
      } else if (normalizedStatus == 'LOST') {
        conditions.add('IsClosed = TRUE AND IsWon = FALSE');
      } else {
        binds.put('statusValue', statusFilter.trim());
        conditions.add('StageName = :statusValue');
      }
    } else if (recordType == 'LEAD') {
      if (normalizedStatus == 'OPEN') {
        conditions.add('IsConverted = FALSE');
      } else if (normalizedStatus == 'CONVERTED') {
        conditions.add('IsConverted = TRUE');
      } else {
        binds.put('statusValue', statusFilter.trim());
        conditions.add('Status = :statusValue');
      }
    } else if (recordType == 'TASK') {
      if (normalizedStatus == 'OPEN') {
        conditions.add('IsClosed = FALSE');
      } else if (normalizedStatus == 'CLOSED') {
        conditions.add('IsClosed = TRUE');
      } else {
        binds.put('statusValue', statusFilter.trim());
        conditions.add('Status = :statusValue');
      }
    } else {
      throw new SalesManagerDataException(
        'Status filtering is supported only for opportunities, leads, and tasks.'
      );
    }
  }

  private static void addDateCondition(
    String recordType,
    String dateWindowInput,
    List<String> conditions
  ) {
    String dateWindow = String.isBlank(dateWindowInput)
      ? 'ALL'
      : normalize(dateWindowInput);
    if (!DATE_WINDOWS.contains(dateWindow)) {
      throw new SalesManagerDataException(
        'Date window must be ALL, OVERDUE, TODAY, NEXT_7_DAYS, or NEXT_30_DAYS.'
      );
    }
    if (dateWindow == 'ALL') {
      return;
    }
    if (recordType == 'ACCOUNT' || recordType == 'LEAD') {
      throw new SalesManagerDataException(
        'Date filtering is supported only for opportunities, tasks, and events.'
      );
    }

    String dateField = recordType == 'OPPORTUNITY'
      ? 'CloseDate'
      : 'ActivityDate';
    if (dateWindow == 'OVERDUE') {
      conditions.add(dateField + ' < TODAY');
      if (recordType == 'OPPORTUNITY') {
        conditions.add('IsClosed = FALSE');
      } else if (recordType == 'TASK') {
        conditions.add('IsClosed = FALSE');
      }
    } else if (dateWindow == 'TODAY') {
      conditions.add(dateField + ' = TODAY');
    } else if (dateWindow == 'NEXT_7_DAYS') {
      conditions.add(dateField + ' = NEXT_N_DAYS:7');
    } else {
      conditions.add(dateField + ' = NEXT_N_DAYS:30');
    }
  }

  private static String buildResponseSummary(
    String recordType,
    String queryMode,
    Integer count,
    Boolean hasMore
  ) {
    String noun = recordType.toLowerCase();
    String summary;
    if (queryMode == 'SUMMARY') {
      summary =
        'Found ' +
        count +
        ' aggregate ' +
        noun +
        (count == 1 ? ' group.' : ' groups.');
    } else {
      summary =
        'Found ' +
        count +
        ' accessible ' +
        noun +
        (count == 1 ? ' record.' : ' records.');
    }
    if (hasMore) {
      summary += ' More results matched; ask the user to narrow the request.';
    }
    return summary;
  }

  private static Response failureResponse(String message) {
    Response response = new Response();
    response.success = false;
    response.summary = 'I could not retrieve those records. ' + message;
    response.recordsJson = '[]';
    response.returnedCount = 0;
    response.hasMore = false;
    return response;
  }

  @TestVisible
  private static TeamContext loadTeamContext() {
    Id managerId = UserInfo.getUserId();
    Map<Id, String> namesById = new Map<Id, String>();
    Set<Id> directReportIds = new Set<Id>();

    for (User teamMember : [
      SELECT Id, Name, ManagerId
      FROM User
      WHERE Id = :managerId OR (ManagerId = :managerId AND IsActive = TRUE)
      WITH USER_MODE
    ]) {
      namesById.put(teamMember.Id, teamMember.Name);
      if (teamMember.Id != managerId) {
        directReportIds.add(teamMember.Id);
      }
    }
    if (!namesById.containsKey(managerId)) {
      throw new SalesManagerDataException(
        'The current user could not be resolved. Check User object access.'
      );
    }

    TeamContext context = new TeamContext();
    context.managerId = managerId;
    context.directReportIds = directReportIds;
    context.namesById = namesById;
    return context;
  }

  private static String normalize(String value) {
    return value == null ? null : value.trim().toUpperCase();
  }

  public class Request {
    @InvocableVariable(
      required=true
      label='Record Type'
      description='The type to retrieve: ACCOUNT, OPPORTUNITY, LEAD, TASK, or EVENT.'
    )
    public String recordType;

    @InvocableVariable(
      label='Query Mode'
      description='LIST returns individual records. SUMMARY returns counts grouped by owner and status; opportunity summaries also include total amount. Defaults to LIST.'
    )
    public String queryMode;

    @InvocableVariable(
      label='Owner Scope'
      description='MINE, DIRECT_REPORTS, or TEAM. Defaults to TEAM. Ignored when Owner Name is supplied.'
    )
    public String ownerScope;

    @InvocableVariable(
      label='Owner Name'
      description='Optional current manager or active direct-report name. Use this for questions about one named team member.'
    )
    public String ownerName;

    @InvocableVariable(
      label='Search Term'
      description='Optional name, company, or subject text to match.'
    )
    public String searchTerm;

    @InvocableVariable(
      label='Status Filter'
      description='Optional exact status. Also supports Opportunity OPEN/CLOSED/WON/LOST, Lead OPEN/CONVERTED, and Task OPEN/CLOSED.'
    )
    public String statusFilter;

    @InvocableVariable(
      label='Date Window'
      description='ALL, OVERDUE, TODAY, NEXT_7_DAYS, or NEXT_30_DAYS. Applies to opportunity close dates and task/event activity dates.'
    )
    public String dateWindow;

    @InvocableVariable(
      label='Maximum Results'
      description='Maximum records to return, from 1 through 25. Defaults to 10.'
    )
    public Integer maxResults;
  }

  public class Response {
    @InvocableVariable(
      label='Success'
      description='True when the records were retrieved successfully.'
    )
    public Boolean success;

    @InvocableVariable(
      label='Summary'
      description='A concise retrieval summary or a safe error message.'
    )
    public String summary;

    @InvocableVariable(
      label='Records JSON'
      description='JSON array of accessible Salesforce records. Use these values to answer the user and never invent missing fields.'
    )
    public String recordsJson;

    @InvocableVariable(
      label='Returned Count'
      description='Number of records returned.'
    )
    public Integer returnedCount;

    @InvocableVariable(
      label='Has More'
      description='True when more records matched than the result limit.'
    )
    public Boolean hasMore;
  }

  private class TeamContext {
    private Id managerId;
    private Set<Id> directReportIds;
    private Map<Id, String> namesById;
  }

  public class SalesManagerDataException extends Exception {
  }
}
