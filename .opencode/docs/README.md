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
```

---

## Subagent Registry

| Agent ID | Invocation | Purpose | Contract |
|---|---|---|---|
| `confluence` | `@confluence` / Task tool | Read and search Confluence Cloud | `contracts/confluence-response.schema.json` |
| `jira` | `@jira` / Task tool | Read and query Jira Cloud | `contracts/jira-response.schema.json` |
| `git-committer` | `@git-committer` | Autonomous Git commit assistant with Conventional Commits + GitFlow | N/A (local utility agent) |

---

## Output Contract Protocol

Every subagent returns a JSON object. The orchestrator MUST:

1. Attempt to parse the output as JSON
2. Check `result.status`:
   - `"success"` → proceed, use `result.summary` for the user-facing response
   - `"partial"` → proceed with caveat, note limitations from `result.summary`
   - `"error"` → surface `result.error.message` to the user and suggest `result.error.remediation`
3. Never fabricate data if parsing fails — report the raw output as an error

---

## Adding a New Subagent

Follow the extension pattern documented in `README.md` at the repository root.
When a new subagent is added, create its knowledge doc in `docs/agents/` and its contract in `docs/contracts/`.
