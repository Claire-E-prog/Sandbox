# Build a Simple Agentforce Agent

This project is a small, working example for learning the parts of an agent
without starting from a large application.

It has exactly:

- **one subagent**: `account_lookup`
- **one action**: `find_my_accounts`

The agent answers read-only questions about Accounts owned by the logged-in
user. It does not update records, call other subagents, or use a complex router.

## The mental model

```text
User question
    |
    v
start_agent
    |
    v
account_lookup subagent
    |
    v
find_my_accounts action
    |
    v
SimpleAccountLookupAction Apex
    |
    v
Accounts the current user can access
```

Each layer has one job:

1. `start_agent` receives the conversation and sends Account questions to the
   subagent.
2. The subagent decides when and how to call the action.
3. The action declaration describes the inputs and outputs available to the
   agent.
4. Apex performs the real Salesforce query and returns grounded data.

## Project files

| File | Purpose |
| --- | --- |
| `force-app/main/default/aiAuthoringBundles/SimpleSalesAgent/SimpleSalesAgent.agent` | Agent instructions, one subagent, and one action |
| `force-app/main/default/classes/SimpleAccountLookupAction.cls` | Read-only Apex implementation |
| `force-app/main/default/classes/SimpleAccountLookupActionTest.cls` | Apex tests |
| `force-app/main/default/permissionsets/Simple_Sales_Agent.permissionset-meta.xml` | Grants access to the Apex action |
| `manifest/package.xml` | Lists the metadata to deploy |

## Build it step by step

### 1. Choose one narrow job

Start with a sentence that names one user, one task, and one data source:

> Help a logged-in salesperson find Accounts they own in Salesforce.

Keeping the first job narrow makes the instructions and security boundary easy
to verify. Add more record types only after this version works.

### 2. Build the Apex action

Open
[`SimpleAccountLookupAction.cls`](force-app/main/default/classes/SimpleAccountLookupAction.cls).
The action has two optional inputs:

- `searchTerm`: part of an Account name
- `maxResults`: number of records to return, capped at 10

`getAccounts` is marked with `@InvocableMethod`, which makes it callable as an
agent action. The query uses `inherited sharing` and `WITH USER_MODE`, so normal
record sharing, object permissions, and field permissions still apply.

The response contains:

- `success`: whether the request worked
- `message`: a short result or safe error message
- `accountsJson`: the accessible Account data used to answer the user

### 3. Test the action

Open
[`SimpleAccountLookupActionTest.cls`](force-app/main/default/classes/SimpleAccountLookupActionTest.cls).
The tests create Accounts, call Apex directly, and check both a successful
search and the maximum result limit.

Run the tests in an authorized org:

```bash
sf apex run test \
  --tests SimpleAccountLookupActionTest \
  --result-format human \
  --wait 10 \
  --target-org my-org
```

### 4. Declare one subagent and one action

Open
[`SimpleSalesAgent.agent`](force-app/main/default/aiAuthoringBundles/SimpleSalesAgent/SimpleSalesAgent.agent).
Read it from top to bottom:

1. `config` gives the agent its API name, label, type, and description.
2. `system` defines the welcome message and global safety rules.
3. `start_agent main` sends relevant requests to `@subagent.account_lookup`.
4. `subagent account_lookup` declares `find_my_accounts`.
5. `target: "apex://SimpleAccountLookupAction"` connects that declaration to
   the Apex class.
6. The subagent's reasoning instructions require action output before it
   answers a Salesforce data question.

The transition in `start_agent` is routing, not a second business action. The
only data action is `find_my_accounts`.

### 5. Grant access

The included `Simple_Sales_Agent` permission set grants access to the Apex
class. It deliberately does not grant Account access. Users still need the
normal Salesforce permissions and sharing access appropriate to their role.

### 6. Deploy and publish

Prerequisites:

- Agentforce, Agentforce Builder, and Employee Agents enabled
- Salesforce CLI with Agentforce DX commands
- an authorized org with API version 66.0 support

Replace `my-org` with your org alias.

Deploy the Apex class, test, and permission set:

```bash
sf project deploy start \
  --metadata ApexClass:SimpleAccountLookupAction \
  --metadata ApexClass:SimpleAccountLookupActionTest \
  --metadata PermissionSet:Simple_Sales_Agent \
  --test-level RunSpecifiedTests \
  --tests SimpleAccountLookupActionTest \
  --target-org my-org
```

Publish the agent bundle:

```bash
sf agent publish authoring-bundle \
  --api-name SimpleSalesAgent \
  --target-org my-org
```

Assign the permission set:

```bash
sf org assign permset \
  --name Simple_Sales_Agent \
  --target-org my-org \
  --on-behalf-of salesperson@example.com
```

In Agentforce Builder, inspect the published version, test it as a representative
user, and activate it when ready.

### 7. Try three prompts

Use a test user who owns at least one Account:

1. `Show my accounts.`
2. `Find my accounts containing Acme.`
3. `Show only two of my accounts.`

Also ask an out-of-scope question such as `Update the Acme account.` The agent
should explain that it is read-only and must not claim it changed anything.

## Add a second action later

Do this only after the first action works. A good second action would be another
read-only task, such as retrieving the current user's open Opportunities.

To add it:

1. Create and test a second `@InvocableMethod` Apex class.
2. Add a second action under `subagent account_lookup`.
3. Add instructions that clearly say when to use each action.
4. Grant the new Apex class in the permission set.

Keep both actions in the same subagent while they serve the same narrow sales
lookup job. Create another subagent only when the new job needs substantially
different instructions or responsibilities.
