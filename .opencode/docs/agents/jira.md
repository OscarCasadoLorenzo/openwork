# Jira Subagent — Agent Knowledge

## Identity

- **Agent ID**: `jira`
- **File**: `.opencode/agents/jira.md`
- **Mode**: `subagent`
- **Model**: `github-copilot/claude-sonnet-4.5`
- **Temperature**: `0.1`

---

## Purpose

The Jira subagent is a **read-only** specialist for Atlassian Jira Cloud. It handles all tasks that require reading, searching, or aggregating data from Jira projects, issues, epics, and sprints.

The orchestrator delegates to this agent whenever the user's request involves Jira data. The agent never creates, updates, or transitions Jira issues.

---

## Capabilities

| Operation | Description |
|---|---|
| `search_issues` | JQL search across projects and issue types |
| `get_issue` | Retrieve full detail of a single issue by key |
| `list_epics` | List all epics in a project |
| `list_sprints` | List sprints for a board (active, future, or closed) |
| `get_backlog` | Retrieve issues in the project backlog |
| `get_project` | Retrieve project metadata |

---

## When to Invoke

Invoke the Jira subagent when the user asks about:
- Specific tickets or issue keys (e.g. "what is PLATFORM-456?")
- Sprint status, velocity, or progress
- Epic breakdown and child issues
- Backlog items or prioritisation
- Issues by assignee, label, status, or priority
- Project health reports or aggregated issue counts

Do NOT invoke for:
- Confluence pages or documentation → use the `confluence` subagent
- Creating or updating Jira issues → not supported in Phase 1
- Tasks that can be resolved locally without API calls

---

## MCP Tools Granted

The agent has access to tools matching the glob `atlassian_jira_*`:

- `atlassian_jira_search_issues`
- `atlassian_jira_get_issue`
- `atlassian_jira_get_epic_issues`
- `atlassian_jira_get_sprints`
- `atlassian_jira_get_active_sprint`
- `atlassian_jira_get_project`
- `atlassian_jira_get_projects`
- `atlassian_jira_get_issue_transitions`
- `atlassian_jira_get_issue_comments`
- `atlassian_jira_get_board`

All `atlassian_confluence_*` tools are explicitly denied.

---

## Output Contract

Every response is a JSON object conforming to:
`.opencode/docs/contracts/jira-response.schema.json`

**Required fields** in all responses:
- `status` — `"success"` | `"error"` | `"partial"`
- `operation` — what was performed

**Required when `status` is `"success"` or `"partial"`**:
- `summary` — concise natural-language summary (≤ 3 sentences)
- Relevant data array: `issues`, `epics`, `sprints`, or `project`

**Required when `status` is `"error"`**:
- `error.code` — machine-readable error category
- `error.message` — human-readable description (include erroneous JQL if applicable)
- `error.remediation` — suggested fix (include corrected JQL if applicable)

---

## Skill

The agent loads the `jira-ops` skill on demand for:
- Complex JQL query construction from natural language
- Epic decomposition and progress calculation
- Sprint velocity analysis across multiple sprints
- Pagination loop handling for large result sets

---

## Constraints

- **No writes**: `edit`, `bash`, `webfetch`, and `task` permissions are all `deny`
- **No cross-agent tool access**: `atlassian_confluence_*` tools are denied
- **No spawning subagents**: `task` permission is `deny`
- **Skill restriction**: Only the `jira-ops` skill is loadable; all others are denied

---

## Orchestrator Usage Example

```
# Orchestrator delegates to jira agent
Task: "Show me all open high-priority bugs in the PLATFORM project for the current sprint"

# Expected response structure
{
  "status": "success",
  "operation": "search_issues",
  "summary": "Found 4 open high-priority bugs in PLATFORM for Platform Sprint 12.",
  "issues": [ ... ],
  "pagination": { "total": 4, "returned": 4, "has_more": false, "start_at": 0 }
}
```
