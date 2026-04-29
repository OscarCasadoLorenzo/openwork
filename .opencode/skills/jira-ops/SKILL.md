---
name: jira-ops
description: Workflow recipes for Jira Cloud operations — JQL query construction, epic decomposition, sprint analysis, and pagination handling. Load this skill when building complex JQL queries, aggregating sprint data, or decomposing epics into their child issues.
license: MIT
compatibility: opencode
metadata:
  domain: atlassian-jira
  version: "1.0"
---

# Jira Operations — Workflow Recipes

## 1. JQL Query Construction

JQL (Jira Query Language) is the structured search syntax for Jira Cloud.

### Common JQL patterns

| Goal | JQL query |
|---|---|
| Open bugs assigned to current user | `assignee = currentUser() AND issuetype = Bug AND status != Done` |
| All issues in active sprint | `sprint in openSprints() AND project = "PLATFORM"` |
| High priority unassigned issues | `priority in (High, Highest) AND assignee is EMPTY` |
| Issues updated in last 24 hours | `updated >= -1d ORDER BY updated DESC` |
| All open issues in an epic | `"Epic Link" = PLATFORM-400 AND status != Done` |
| Issues by label | `labels = "critical" AND project = "PLATFORM"` |
| Overdue issues | `duedate < now() AND status != Done` |
| Issues created this sprint | `project = "PLATFORM" AND sprint = "Platform Sprint 12"` |
| Blockers | `issueType = Bug AND priority = Highest AND status in (Open, "In Progress")` |

### JQL operators reference

| Operator | Meaning | Example |
|---|---|---|
| `=` | Exact match | `project = "PLATFORM"` |
| `!=` | Not equal | `status != Done` |
| `~` | Contains text | `summary ~ "payment"` |
| `IN` | Match any in list | `status IN ("In Progress", "Review")` |
| `NOT IN` | Exclude list | `status NOT IN (Done, Closed)` |
| `is EMPTY` | Field has no value | `assignee is EMPTY` |
| `is not EMPTY` | Field has a value | `fixVersion is not EMPTY` |
| `>=` / `<=` | Date comparison | `created >= -7d` |
| `AND` | Both conditions | `project = "PLATFORM" AND status = "In Progress"` |
| `OR` | Either condition | `priority = High OR priority = Highest` |
| `ORDER BY` | Sort results | `ORDER BY priority DESC, updated DESC` |

### Translating natural language to JQL

| User says | JQL to use |
|---|---|
| "My open tickets" | `assignee = currentUser() AND status != Done` |
| "Critical bugs this sprint" | `issuetype = Bug AND priority in (High, Highest) AND sprint in openSprints()` |
| "What's in the backlog?" | `project = "PROJECT" AND sprint is EMPTY AND status = "To Do" ORDER BY priority DESC` |
| "Tickets blocked or at risk" | `labels in (blocked, at-risk) AND status != Done` |
| "All open issues for epic X" | `"Epic Link" = <epic_key> AND status != Done` |
| "Show me done this week" | `status = Done AND resolved >= -7d ORDER BY resolved DESC` |

### Jira function reference

| Function | Meaning |
|---|---|
| `currentUser()` | The authenticated user |
| `openSprints()` | All currently active sprints |
| `closedSprints()` | All completed sprints |
| `futureSprints()` | All upcoming sprints |
| `now()` | Current date/time |
| `startOfDay()` | Start of today |
| `endOfDay()` | End of today |
| `startOfWeek()` | Start of current week |

---

## 2. Epic Decomposition

### Get all issues in an epic

1. Get the epic key (e.g. `PLATFORM-400`)
2. Call `atlassian_jira_search_issues` with JQL: `"Epic Link" = PLATFORM-400`
3. For each issue, extract: `key`, `summary`, `status`, `assignee`, `story_points`
4. Group by `status` for a progress breakdown

### Epic progress summary pattern

Compute from the retrieved issues:
```
total_issues = issues.length
done_issues  = issues.filter(i => i.status == "Done").length
in_progress  = issues.filter(i => i.status == "In Progress").length
not_started  = total_issues - done_issues - in_progress
progress_pct = (done_issues / total_issues) * 100
```

Include this breakdown in the `summary` field of the response.

---

## 3. Sprint Analysis

### Active sprint health check

1. Call `atlassian_jira_get_active_sprint` to get the current sprint ID and dates
2. Call `atlassian_jira_search_issues` with JQL: `sprint = <sprint_id>`
3. Categorise issues:
   - **Done**: `status = Done`
   - **In Progress**: `status = "In Progress"`
   - **Blocked**: `labels = blocked`
   - **Not Started**: `status = "To Do"`
4. Calculate:
   - Days remaining in sprint: `end_date - today`
   - Completion rate: `done / total * 100`
   - Story points completed vs total (if story points are used)

### Sprint velocity pattern

To compare the last 3 completed sprints:
1. Call `atlassian_jira_get_sprints` with `state=closed`
2. Take the 3 most recently closed sprints
3. For each sprint, call `atlassian_jira_search_issues` with `sprint = <id> AND status = Done`
4. Sum `story_points` for each sprint
5. Report average as velocity

---

## 4. Pagination Handling

### Standard Jira pagination loop

Jira search endpoints use `startAt` + `maxResults` pagination. Default `maxResults` is 50.

```
results = []
startAt = 0
maxResults = 50

loop:
  response = search_issues(startAt=startAt, maxResults=maxResults)
  results += response.issues
  if startAt + response.issues.length >= response.total:
    break
  startAt += maxResults
```

Always populate the response contract's `pagination` object:
```json
{
  "pagination": {
    "total": <response.total>,
    "returned": <results.length>,
    "has_more": <startAt + returned < total>,
    "start_at": <startAt>
  }
}
```

### Capping results

Unless the user asks for all results, cap at 50 issues per response. Set `has_more: true` and document `start_at` so the orchestrator can request additional pages if needed.

---

## 5. Common Error Patterns

| HTTP status | `error.code` | Likely cause |
|---|---|---|
| 400 | `INVALID_JQL` | JQL syntax error — check field names and operators |
| 401 | `AUTH_FAILED` | Invalid or expired API token |
| 403 | `PERMISSION_DENIED` | Account lacks access to the project |
| 404 | `NOT_FOUND` | Issue key or project key does not exist |
| 429 | `RATE_LIMITED` | Too many requests — wait and retry |
| 500/503 | `NETWORK_ERROR` | Atlassian service issue — retry once |

### Common JQL mistakes to avoid

| Wrong | Correct | Reason |
|---|---|---|
| `assigneed = currentUser()` | `assignee = currentUser()` | Typo in field name |
| `status = "in progress"` | `status = "In Progress"` | Status values are case-sensitive |
| `created > today` | `created >= startOfDay()` | Use Jira functions, not `today` |
| `epic = PLATFORM-400` | `"Epic Link" = PLATFORM-400` | Epic field name requires quotes |
| `sprint = active` | `sprint in openSprints()` | Use function, not literal |

For `INVALID_JQL` errors, always include the erroneous query in `error.message` and the corrected version in `error.remediation`.

For `RATE_LIMITED`: mention in `remediation` that the user should wait 30 seconds before retrying.
