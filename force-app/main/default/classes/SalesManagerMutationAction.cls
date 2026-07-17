/**
 * Confirmed, user-mode mutations for the Sales Manager Assistant.
 *
 * Supported operations:
 * - UPDATE_RECORD: update allowlisted fields on a supported sales record.
 * - CREATE_TASK: create a task assigned to the manager or an active direct report.
 * - ASSIGN_TASK: reassign an existing task to the manager or an active direct report.
 */
public inherited sharing class SalesManagerMutationAction {
  private static final Integer MAX_REQUESTS = 25;
  private static final Integer MAX_FIELDS_PER_UPDATE = 10;
  private static final Set<String> OPERATIONS = new Set<String>{
    'UPDATE_RECORD',
    'CREATE_TASK',
    'ASSIGN_TASK'
  };
  private static final Map<String, Set<String>> ALLOWED_FIELDS = new Map<String, Set<String>>{
    'Account' => new Set<String>{
      'Name',
      'Type',
      'Industry',
      'AnnualRevenue',
      'Description'
    },
    'Opportunity' => new Set<String>{
      'Name',
      'StageName',
      'Amount',
      'CloseDate',
      'NextStep',
      'Description'
    },
    'Lead' => new Set<String>{
      'FirstName',
      'LastName',
      'Company',
      'Status',
      'Rating',
      'Email',
      'Phone',
      'Title',
      'Description'
    },
    'Task' => new Set<String>{
      'Subject',
      'Status',
      'Priority',
      'ActivityDate',
      'Description'
    },
    'Event' => new Set<String>{
      'Subject',
      'StartDateTime',
      'EndDateTime',
      'Location',
      'Description'
    }
  };

  @InvocableMethod(
    label='Change Sales Manager Records'
    description='After user confirmation, updates allowlisted sales record fields, creates a task, or assigns an existing task to the current manager or an active direct report.'
  )
  public static List<Response> changeRecords(List<Request> requests) {
    if (requests == null || requests.isEmpty()) {
      return new List<Response>();
    }
    if (requests.size() > MAX_REQUESTS) {
      throw new SalesManagerMutationException(
        'A maximum of 25 requests is supported per invocation.'
      );
    }

    TeamContext team = loadTeamContext();
    List<Response> responses = new List<Response>();
    for (Request request : requests) {
      try {
        responses.add(executeRequest(request, team));
      } catch (SalesManagerMutationException exceptionValue) {
        responses.add(failureResponse(exceptionValue.getMessage()));
      } catch (DmlException exceptionValue) {
        responses.add(
          failureResponse(
            'Salesforce rejected the change. Check record access, field permissions, validation rules, and required values.'
          )
        );
      } catch (QueryException exceptionValue) {
        responses.add(
          failureResponse(
            'Salesforce denied access needed for this change. Check the user\'s object and field permissions.'
          )
        );
      } catch (Exception exceptionValue) {
        responses.add(
          failureResponse(
            'An unexpected error occurred while changing the sales record.'
          )
        );
      }
    }
    return responses;
  }

  private static Response executeRequest(Request request, TeamContext team) {
    if (request == null || String.isBlank(request.operation)) {
      throw new SalesManagerMutationException('Operation is required.');
    }
    String operation = request.operation.trim().toUpperCase();
    if (!OPERATIONS.contains(operation)) {
      throw new SalesManagerMutationException(
        'Operation must be UPDATE_RECORD, CREATE_TASK, or ASSIGN_TASK.'
      );
    }

    if (operation == 'UPDATE_RECORD') {
      return updateRecord(request, team);
    }
    if (operation == 'CREATE_TASK') {
      return createTask(request, team);
    }
    return assignTask(request, team);
  }

  private static Response updateRecord(Request request, TeamContext team) {
    Id recordId = parseId(request.recordId, 'Record Id');
    String objectName = recordId.getSObjectType().getDescribe().getName();
    if (!ALLOWED_FIELDS.containsKey(objectName)) {
      throw new SalesManagerMutationException(
        'Only Account, Opportunity, Lead, Task, and Event records can be updated.'
      );
    }
    verifyTeamOwnedRecord(recordId, objectName, team);
    if (String.isBlank(request.updatesJson)) {
      throw new SalesManagerMutationException(
        'Updates JSON is required for UPDATE_RECORD.'
      );
    }

    Map<String, Object> updates;
    try {
      updates = (Map<String, Object>) JSON.deserializeUntyped(
        request.updatesJson
      );
    } catch (Exception exceptionValue) {
      throw new SalesManagerMutationException(
        'Updates JSON must be a JSON object of field API names and new values.'
      );
    }
    if (updates == null || updates.isEmpty()) {
      throw new SalesManagerMutationException(
        'At least one field update is required.'
      );
    }
    if (updates.size() > MAX_FIELDS_PER_UPDATE) {
      throw new SalesManagerMutationException(
        'A maximum of 10 fields can be updated at once.'
      );
    }

    Schema.SObjectType objectType = recordId.getSObjectType();
    Map<String, Schema.SObjectField> fieldsByName = objectType
      .getDescribe()
      .fields.getMap();
    SObject recordToUpdate = objectType.newSObject(recordId);
    for (String fieldName : updates.keySet()) {
      if (!ALLOWED_FIELDS.get(objectName).contains(fieldName)) {
        throw new SalesManagerMutationException(
          'Field ' + fieldName + ' is not allowed for ' + objectName + '.'
        );
      }
      Schema.DescribeFieldResult fieldDescription = fieldsByName
        .get(fieldName)
        .getDescribe();
      recordToUpdate.put(
        fieldName,
        convertValue(updates.get(fieldName), fieldDescription)
      );
    }

    update as user recordToUpdate;
    return successResponse(
      recordId,
      'Updated ' + objectName + ' ' + recordId + '.',
      JSON.serialize(recordToUpdate)
    );
  }

  private static Response createTask(Request request, TeamContext team) {
    if (String.isBlank(request.subject)) {
      throw new SalesManagerMutationException(
        'Task subject is required for CREATE_TASK.'
      );
    }
    Id assigneeId = resolveAssigneeId(request.assigneeName, team);
    Task taskToCreate = new Task(
      Subject = request.subject.trim(),
      OwnerId = assigneeId
    );
    if (!String.isBlank(request.dueDate)) {
      taskToCreate.ActivityDate = parseDate(request.dueDate, 'Due Date');
    }
    if (!String.isBlank(request.status)) {
      taskToCreate.Status = request.status.trim();
    }
    if (!String.isBlank(request.priority)) {
      taskToCreate.Priority = request.priority.trim();
    }
    if (!String.isBlank(request.description)) {
      taskToCreate.Description = request.description;
    }
    if (!String.isBlank(request.relatedRecordId)) {
      taskToCreate.WhatId = parseId(
        request.relatedRecordId,
        'Related Record Id'
      );
    }
    if (!String.isBlank(request.personRecordId)) {
      Id personId = parseId(request.personRecordId, 'Person Record Id');
      Schema.SObjectType personType = personId.getSObjectType();
      if (personType != Contact.SObjectType && personType != Lead.SObjectType) {
        throw new SalesManagerMutationException(
          'Person Record Id must identify a Contact or Lead.'
        );
      }
      taskToCreate.WhoId = personId;
    }

    insert as user taskToCreate;
    return successResponse(
      taskToCreate.Id,
      'Created task "' +
        taskToCreate.Subject +
        '" and assigned it to ' +
        team.namesById.get(assigneeId) +
        '.',
      JSON.serialize(taskToCreate)
    );
  }

  private static Response assignTask(Request request, TeamContext team) {
    Id taskId = parseId(request.recordId, 'Record Id');
    if (taskId.getSObjectType() != Task.SObjectType) {
      throw new SalesManagerMutationException(
        'ASSIGN_TASK requires a Task record Id.'
      );
    }
    verifyTeamOwnedRecord(taskId, 'Task', team);
    Id assigneeId = resolveAssigneeId(request.assigneeName, team);
    Task taskToAssign = new Task(Id = taskId, OwnerId = assigneeId);
    update as user taskToAssign;
    return successResponse(
      taskId,
      'Assigned task ' + taskId + ' to ' + team.namesById.get(assigneeId) + '.',
      JSON.serialize(taskToAssign)
    );
  }

  private static Object convertValue(
    Object rawValue,
    Schema.DescribeFieldResult fieldDescription
  ) {
    if (rawValue == null) {
      return null;
    }
    String stringValue = String.valueOf(rawValue);
    Schema.DisplayType fieldType = fieldDescription.getType();
    try {
      if (fieldType == Schema.DisplayType.DATE) {
        return Date.valueOf(stringValue);
      }
      if (fieldType == Schema.DisplayType.DATETIME) {
        return Datetime.valueOf(stringValue);
      }
      if (
        fieldType == Schema.DisplayType.CURRENCY ||
        fieldType == Schema.DisplayType.DOUBLE ||
        fieldType == Schema.DisplayType.PERCENT
      ) {
        return Decimal.valueOf(stringValue);
      }
      if (fieldType == Schema.DisplayType.INTEGER) {
        return Integer.valueOf(stringValue);
      }
      if (fieldType == Schema.DisplayType.BOOLEAN) {
        return Boolean.valueOf(stringValue);
      }
      return stringValue;
    } catch (Exception exceptionValue) {
      throw new SalesManagerMutationException(
        'Value "' +
          stringValue +
          '" is invalid for field ' +
          fieldDescription.getName() +
          '.'
      );
    }
  }

  private static void verifyTeamOwnedRecord(
    Id recordId,
    String objectName,
    TeamContext team
  ) {
    List<SObject> records = Database.queryWithBinds(
      'SELECT OwnerId FROM ' + objectName + ' WHERE Id = :recordId LIMIT 1',
      new Map<String, Object>{ 'recordId' => recordId },
      AccessLevel.USER_MODE
    );
    if (records.isEmpty()) {
      throw new SalesManagerMutationException(
        'The record was not found or is not accessible.'
      );
    }
    Id ownerId = (Id) records[0].get('OwnerId');
    if (!team.namesById.containsKey(ownerId)) {
      throw new SalesManagerMutationException(
        'The record must be owned by the current manager or an active direct report.'
      );
    }
  }

  private static Id resolveAssigneeId(String assigneeName, TeamContext team) {
    if (String.isBlank(assigneeName)) {
      throw new SalesManagerMutationException('Assignee name is required.');
    }
    String requestedName = assigneeName.trim().toLowerCase();
    Set<Id> exactMatches = new Set<Id>();
    Set<Id> partialMatches = new Set<Id>();
    for (Id userId : team.namesById.keySet()) {
      String candidate = team.namesById.get(userId);
      if (candidate.toLowerCase() == requestedName) {
        exactMatches.add(userId);
      } else if (candidate.toLowerCase().contains(requestedName)) {
        partialMatches.add(userId);
      }
    }
    Set<Id> matches = exactMatches.isEmpty() ? partialMatches : exactMatches;
    if (matches.isEmpty()) {
      throw new SalesManagerMutationException(
        'No active direct report or current manager matched assignee "' +
          assigneeName +
          '".'
      );
    }
    if (matches.size() > 1) {
      throw new SalesManagerMutationException(
        'Assignee "' +
          assigneeName +
          '" matched multiple team members. Ask for a more specific name.'
      );
    }
    return new List<Id>(matches)[0];
  }

  private static Id parseId(String inputValue, String label) {
    if (String.isBlank(inputValue)) {
      throw new SalesManagerMutationException(label + ' is required.');
    }
    try {
      return Id.valueOf(inputValue.trim());
    } catch (Exception exceptionValue) {
      throw new SalesManagerMutationException(
        label + ' must be a valid Salesforce Id.'
      );
    }
  }

  private static Date parseDate(String inputValue, String label) {
    try {
      return Date.valueOf(inputValue.trim());
    } catch (Exception exceptionValue) {
      throw new SalesManagerMutationException(
        label + ' must use YYYY-MM-DD format.'
      );
    }
  }

  private static TeamContext loadTeamContext() {
    Id managerId = UserInfo.getUserId();
    TeamContext context = new TeamContext();
    context.namesById = new Map<Id, String>();
    for (User teamMember : [
      SELECT Id, Name
      FROM User
      WHERE Id = :managerId OR (ManagerId = :managerId AND IsActive = TRUE)
      WITH USER_MODE
    ]) {
      context.namesById.put(teamMember.Id, teamMember.Name);
    }
    if (!context.namesById.containsKey(managerId)) {
      throw new SalesManagerMutationException(
        'The current user could not be resolved. Check User object access.'
      );
    }
    return context;
  }

  private static Response successResponse(
    Id recordId,
    String message,
    String recordJson
  ) {
    Response response = new Response();
    response.success = true;
    response.message = message;
    response.recordId = String.valueOf(recordId);
    response.recordJson = recordJson;
    return response;
  }

  private static Response failureResponse(String message) {
    Response response = new Response();
    response.success = false;
    response.message = 'I could not make that change. ' + message;
    return response;
  }

  public class Request {
    @InvocableVariable(
      required=true
      label='Operation'
      description='UPDATE_RECORD, CREATE_TASK, or ASSIGN_TASK.'
    )
    public String operation;

    @InvocableVariable(
      label='Record Id'
      description='Record to update, or existing Task to assign.'
    )
    public String recordId;

    @InvocableVariable(
      label='Updates JSON'
      description='For UPDATE_RECORD, a JSON object with allowlisted field API names and new values. Dates use YYYY-MM-DD and datetimes use YYYY-MM-DD HH:MM:SS.'
    )
    public String updatesJson;

    @InvocableVariable(
      label='Assignee Name'
      description='For task operations, the current manager or active direct-report name.'
    )
    public String assigneeName;

    @InvocableVariable(
      label='Task Subject'
      description='Required task subject for CREATE_TASK.'
    )
    public String subject;

    @InvocableVariable(
      label='Due Date'
      description='Optional task due date in YYYY-MM-DD format.'
    )
    public String dueDate;

    @InvocableVariable(
      label='Task Status'
      description='Optional exact Task status. Omit to use the Salesforce default.'
    )
    public String status;

    @InvocableVariable(
      label='Task Priority'
      description='Optional exact Task priority. Omit to use the Salesforce default.'
    )
    public String priority;

    @InvocableVariable(
      label='Description'
      description='Optional task description.'
    )
    public String description;

    @InvocableVariable(
      label='Related Record Id'
      description='Optional Account, Opportunity, or other WhatId for a new task.'
    )
    public String relatedRecordId;

    @InvocableVariable(
      label='Person Record Id'
      description='Optional Contact or Lead WhoId for a new task.'
    )
    public String personRecordId;
  }

  public class Response {
    @InvocableVariable(
      label='Success'
      description='True when the change completed successfully.'
    )
    public Boolean success;

    @InvocableVariable(
      label='Message'
      description='Outcome message suitable for the user.'
    )
    public String message;

    @InvocableVariable(
      label='Record Id'
      description='Id of the changed or created record.'
    )
    public String recordId;

    @InvocableVariable(
      label='Record JSON'
      description='JSON containing the values submitted in the successful change.'
    )
    public String recordJson;
  }

  private class TeamContext {
    private Map<Id, String> namesById;
  }

  public class SalesManagerMutationException extends Exception {
  }
}
