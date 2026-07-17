# Sales Manager Assistant Question Bank

Use these questions to demonstrate or test the Sales Manager Assistant.

## Opportunities and pipeline

- Show my open opportunities closing this month.
- What is my total open pipeline?
- Summarize our pipeline by owner and stage.
- Which opportunities are overdue?
- Show Jordan's opportunities in the Proposal stage.
- Compare opportunity counts across my team.
- How much pipeline does each direct report own?
- Show the top 20 matching opportunities.

## Leads

- How many leads does my team have by status?
- List my newest leads.
- Show Priya's leads for Acme.
- Summarize open leads owned by my direct reports.
- How many converted leads does my team have?

## Accounts

- Which accounts are owned by my direct reports?
- Find team accounts containing "Global."
- Show my recently active accounts.
- List accounts owned by Jordan.
- Summarize our accounts by owner and type.

## Tasks and follow-ups

- What tasks are due today?
- Which direct reports have overdue tasks?
- Show Alex's open follow-ups.
- List my open tasks for the next seven days.
- Compare open task counts across my team.

## Events and meetings

- What meetings does my team have this week?
- List my events for today.
- Show Jordan's upcoming events.
- How many events does each team member have this month?
- Find team events containing "QBR."

## Cross-team questions

- What sales work needs attention today?
- Compare my workload with my direct reports.
- Which team members have the most open opportunities?
- Give me a summary of our current pipeline and overdue tasks.
- Show activities related to Acme.

## Expected boundaries

The agent is read-only. It should decline mutation requests such as:

- Update this opportunity to Closed Won.
- Create a follow-up task for tomorrow.
- Reassign this account to Jordan.
- Delete this lead.

Answers are limited to records and fields available through the logged-in user's
Salesforce sharing, object permissions, and field permissions. The agent should
describe an empty result as "no accessible matching records" rather than claiming
that no records exist.
