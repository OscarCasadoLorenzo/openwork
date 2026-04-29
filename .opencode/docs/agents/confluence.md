# Confluence Subagent — Agent Knowledge

## Identity

- **Agent ID**: `confluence`
- **File**: `.opencode/agents/confluence.md`
- **Mode**: `subagent`
- **Model**: `github-copilot/claude-sonnet-4.5`
- **Temperature**: `0.1`

---

## Purpose

The Confluence subagent is a **read-only** specialist for Atlassian Confluence Cloud. It handles all tasks that require reading, searching, or extracting content from Confluence spaces and pages.

The orchestrator delegates to this agent whenever the user's request involves Confluence content. The agent never writes, creates, or modifies Confluence pages.

---

## Capabilities

| Operation | Description |
|---|---|
| `search` | Full-text or CQL search across one or more spaces |
| `get_page` | Retrieve complete content of a specific page by ID or title |
| `list_space` | List all accessible Confluence spaces |
| `list_children` | List child pages of a given parent page |
| `get_metadata` | Retrieve page metadata (author, version, labels) without full content |

---

## When to Invoke

Invoke the Confluence subagent when the user asks about:
- Documentation (runbooks, how-to guides, onboarding docs)
- Architecture decisions or design specs stored in Confluence
- Team knowledge bases or project wikis
- Finding pages by keyword, label, or author
- Getting the content of a specific Confluence page
- Navigating a Confluence space hierarchy

Do NOT invoke for:
- Jira issues, epics, or sprints → use the `jira` subagent
- Creating or editing Confluence pages → not supported in Phase 1
- Tasks that can be resolved locally without API calls

---

## MCP Tools Granted

The agent has access to tools matching the glob `atlassian_confluence_*`:

- `atlassian_confluence_search`
- `atlassian_confluence_get_page`
- `atlassian_confluence_get_pages`
- `atlassian_confluence_get_child_pages`
- `atlassian_confluence_get_spaces`
- `atlassian_confluence_get_space`
- `atlassian_confluence_get_page_labels`
- `atlassian_confluence_get_page_ancestors`

All `atlassian_jira_*` tools are explicitly denied.

---

## Output Contract

Every response is a JSON object conforming to:
`.opencode/docs/contracts/confluence-response.schema.json`

**Required fields** in all responses:
- `status` — `"success"` | `"error"` | `"partial"`
- `operation` — what was performed

**Required when `status` is `"success"` or `"partial"`**:
- `summary` — concise natural-language summary (≤ 3 sentences)
- `pages` — array of page objects (may be empty if no results found)

**Required when `status` is `"error"`**:
- `error.code` — machine-readable error category
- `error.message` — human-readable description
- `error.remediation` — suggested fix

---

## Skill

The agent loads the `confluence-ops` skill on demand for:
- Recursive space traversal
- CQL query construction from natural language
- Pagination loop handling
- Content extraction (stripping Confluence markup)

---

## Constraints

- **No writes**: `edit`, `bash`, `webfetch`, and `task` permissions are all `deny`
- **No cross-agent tool access**: `atlassian_jira_*` tools are denied
- **No spawning subagents**: `task` permission is `deny`
- **Skill restriction**: Only the `confluence-ops` skill is loadable; all others are denied

---

## Orchestrator Usage Example

```
# Orchestrator delegates to confluence agent
Task: "Find the Q3 architecture decision records in the Engineering Confluence space"

# Expected response structure
{
  "status": "success",
  "operation": "search",
  "summary": "Found 3 pages tagged as architecture decisions in the Engineering space, all updated in Q3 2025.",
  "pages": [ ... ]
}
```
