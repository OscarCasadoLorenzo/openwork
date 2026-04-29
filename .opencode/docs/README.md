# Multiagent System — Knowledge Store

This directory is the structured knowledge store for the multiagent system.
It is loaded into every OpenCode session via the `instructions` glob in `opencode.json`.

Do not use this directory for runtime outputs or temporary data.
All files here are source-of-truth documentation, committed to git.

---

## Directory Structure

```
.opencode/docs/
├── README.md                  ← This file — always loaded, provides the index
├── agents/
│   ├── confluence.md          ← Confluence subagent: capabilities, contracts, usage
│   ├── jira.md                ← Jira subagent: capabilities, contracts, usage
│   └── git-committer.md       ← Git Committer subagent: autonomous commit assistant
├── contracts/
│   ├── confluence-response.schema.json   ← JSON output contract for Confluence subagent
│   └── jira-response.schema.json         ← JSON output contract for Jira subagent
└── decisions/
    └── ADR-001-architecture.md           ← Architecture Decision Record #1

(root)/docs/
└── (test documentation and reports)
```

---

## MCP Tool Registry

| Tool Namespace | Purpose | Used For |
|---|---|---|
| `confluence_datacenter_*` | Read and search Confluence Data Center | Documentation, runbooks, specs, architecture decisions |
| `jira_datacenter_*` | Read and query Jira Data Center | Issues, epics, sprints, project status, backlogs |
| `atlassian_confluence_*` | Confluence Cloud (via mcp-atlassian) | Alternative Confluence Cloud access |
| `atlassian_jira_*` | Jira Cloud (via mcp-atlassian) | Alternative Jira Cloud access |

**Note**: The orchestrator has direct access to all MCP tools and uses them based on the user's request context

---

## Adding a New Integration

Follow the extension pattern documented in `README.md` at the repository root.
When adding a new integration, document the MCP tool namespace and usage patterns.
