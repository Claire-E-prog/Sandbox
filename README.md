# Sales Manager Assistant

An Agentforce Employee Agent that answers questions about a logged-in sales
manager's accounts, opportunities, leads, tasks, events, and the same records
owned by active direct reports. It can also make confirmed, allowlisted field
updates and create or reassign tasks within the manager's direct team.

## What is included

- `SalesManagerAssistant.agent`: Agent Script source for an
  `AgentforceEmployeeAgent`.
- `SalesManagerDataAction`: one allowlisted, read-only Apex action for all
  supported record types.
- `SalesManagerMutationAction`: a user-mode Apex action for confirmed updates
  and task assignment.
- `Sales_Manager_Agent`: permission set granting access to both Apex actions.
- Apex tests for owner scope, filtering, validation, result limits, and named
  direct-report resolution, plus update and task-assignment tests.

The action supports:

| Input | Values |
| --- | --- |
| Record type | `ACCOUNT`, `OPPORTUNITY`, `LEAD`, `TASK`, `EVENT` |
| Query mode | `LIST` for details; `SUMMARY` for database-computed owner/status totals |
| Owner scope | `MINE`, `DIRECT_REPORTS`, `TEAM` |
| Named owner | Current manager or an active direct report |
| Date window | `ALL`, `OVERDUE`, `TODAY`, `NEXT_7_DAYS`, `NEXT_30_DAYS` |
| Status | Exact Opportunity stage, Lead status, or Task status |
| Result size | 1–25 records |

Confirmed mutations support:

- allowlisted field updates to team-owned Account, Opportunity, Lead, Task, and
  Event records;
- creating a Task assigned to the manager or an active direct report; and
- reassigning an existing Task to the manager or an active direct report.

## Security model

The Employee Agent runs as the logged-in user. Both Apex actions use inherited
sharing. Reads use `Database.queryWithBinds(..., AccessLevel.USER_MODE)`, and
changes use user-mode DML, so they enforce:

- record sharing;
- object CRUD;
- field-level security; and
- a strict owner allowlist containing only the current user and active users
  whose `ManagerId` is the current user's Id.

Every mutation action declares `require_user_confirmation: True`. Generic record
updates use per-object field allowlists and cannot change ownership. Task
assignment resolves the assignee against the current manager and active direct
reports. Existing-record changes additionally verify that the owner is the
manager or an active direct report. Delete operations are not implemented.

`ManagerId` identifies direct reports but does **not** grant record access.
Configure your role hierarchy, sharing rules, territories, or account/opportunity
teams so managers can read the intended report-owned records. In most orgs,
role-hierarchy access should align each seller's `UserRoleId` with the management
structure. Do not replace the user-mode query with system-mode Apex to work
around sharing.

The included permission set grants only Apex class access. Managers still need
their normal read/edit/create access to the supported objects and fields,
including permission to assign Tasks to the selected users.

## Prerequisites

- An org with Agentforce, Agentforce Builder, and Agentforce Employee Agents
  enabled.
- Salesforce CLI with the Agentforce DX commands.
- API version 66.0 support.
- Authorized target org and manager users with appropriate Salesforce licenses.
- `User.ManagerId` populated for direct reports.

## Deploy and publish

Replace `my-org` with an authorized org alias.

1. Deploy and test the Apex dependency and permission set:

   ```bash
   sf project deploy start \
     --metadata ApexClass:SalesManagerDataAction \
     --metadata ApexClass:SalesManagerDataActionTest \
     --metadata ApexClass:SalesManagerMutationAction \
     --metadata ApexClass:SalesManagerMutationActionTest \
     --metadata PermissionSet:Sales_Manager_Agent \
     --test-level RunSpecifiedTests \
     --tests SalesManagerDataActionTest \
     --tests SalesManagerMutationActionTest \
     --target-org my-org
   ```

2. Publish the Agent Script authoring bundle:

   ```bash
   sf agent publish authoring-bundle \
     --api-name SalesManagerAssistant \
     --target-org my-org
   ```

3. Assign action access to each manager:

   ```bash
   sf org assign permset \
     --name Sales_Manager_Agent \
     --target-org my-org \
     --on-behalf-of manager@example.com
   ```

4. In Agentforce Builder, inspect the published draft/version, test it as a
   representative manager, and activate it when ready.

## Suggested acceptance tests

See [QUESTION_BANK.md](QUESTION_BANK.md) for a larger set of demonstration and
acceptance-test prompts. Test with a manager who owns records and has at least
one active direct report:

- "Show my open opportunities closing in the next 30 days."
- "What overdue tasks do my direct reports have?"
- "Summarize Jordan's leads."
- "Compare our pipeline by owner."
- "What meetings does my team have today?"
- "Update this opportunity to Closed Won." (The agent must identify the exact
  record, show the proposed change, require confirmation, and report the action
  result.)
- "Create a follow-up task for Jordan due tomorrow."
- "Assign this existing task to Priya."

Also verify that inaccessible records and fields never appear, ambiguous names
prompt for clarification, broad results disclose when they were truncated,
mutations require confirmation, and failed mutations are never reported as
successful.
