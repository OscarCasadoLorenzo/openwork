# Multiagent Work — Enterprise Orchestration Template

A scalable, OpenCode-native template for coordinating multiagent workflows in enterprise environments. Designed to manage a primary orchestrator and encapsulated, specialized subagents that interact with tools like Confluence and Jira — with a clear path to extend to additional integrations over time.

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
  - [Layer Map](#layer-map)
  - [Repository Structure](#repository-structure)
- [Acceptance Criteria Log](#acceptance-criteria-log)
- [Decision Log](#decision-log)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Environment Setup](#environment-setup)
  - [Validation](#validation)
- [Agents](#agents)
  - [Orchestrator (Primary Build Agent)](#orchestrator-primary-build-agent)
  - [Confluence Subagent](#confluence-subagent)
  - [Jira Subagent](#jira-subagent)
- [Skills](#skills)
- [Output Contracts](#output-contracts)
- [MCP Integration](#mcp-integration)
- [Extending the System](#extending-the-system)
- [Roadmap](#roadmap)

---

## Overview

This repository is the **core template** for multiagent coordination at the enterprise level. It uses [OpenCode](https://opencode.ai) as the primary interface and coordination engine.

The goal is to increase developer autonomy by providing:

- A structured, version-controlled agent configuration
- Deterministic workflows via typed output contracts
- Fully encapsulated subagent contexts
- A clear extension pattern for adding new integrations

All important data, decisions, and structural knowledge live in `.opencode/docs/` — not in a monolithic `AGENTS.md`.

---

## Architecture

### Layer Map

```
┌─────────────────────────────────────────────────────────┐
│                   ORCHESTRATOR LAYER                     │
│   Primary Build Agent  ·  AGENTS.md  ·  opencode.json   │
│    Direct access to MCP tools, formats user responses    │
└──────────────────────────┬──────────────────────────────┘
                           │ uses MCP tools directly
          ┌────────────────┼─────────────────┐
          ▼                ▼                 ▼
┌──────────────────────────────────────────────────────┐
│                 MCP TOOL LAYER                        │
│   confluence_datacenter_*  │  jira_datacenter_*      │
│   atlassian_confluence_*   │  atlassian_jira_*       │
└──────────────────────────┬───────────────────────────┘
                           │
                           ▼
            ┌───────────────────────┐
            │   MCP SERVERS          │
            │   atlassian-datacenter │
            │   mcp-atlassian        │
            └───────────┬────────────┘
                        │
                        ▼
            ┌───────────────────────┐
            │   ATLASSIAN APIs      │
            │   Confluence & Jira   │
            └───────────────────────┘
```

### Repository Structure

```
multiagent-work/
│
├── README.md                          # This file
├── AGENTS.md                          # Thin orchestrator rules; references .opencode/docs/
├── .env.example                       # Credential contract template (committed to git)
│
├── scripts/
│   └── validate.sh                    # Pre-flight validation: env vars, API reachability, dirs
│
└── .opencode/
    ├── opencode.json                  # Central config: model, MCP server, agent registry,
    │                                  # tool scoping, task permissions, instructions index
    │
    ├── agents/
    │   ├── confluence.md              # Confluence subagent definition
    │   └── jira.md                    # Jira subagent definition
    │
    ├── skills/
    │   ├── confluence-ops/
    │   │   └── SKILL.md               # Confluence workflow recipes (loaded on demand)
    │   └── jira-ops/
    │       └── SKILL.md               # Jira workflow recipes (loaded on demand)
    │
    └── docs/                          # Structured knowledge store (replaces monolithic AGENTS.md)
        ├── README.md                  # System overview for AI context
        ├── agents/
        │   ├── confluence.md          # Capabilities, output contracts, usage examples
        │   └── jira.md                # Capabilities, output contracts, usage examples
        ├── contracts/
        │   ├── confluence-response.schema.json   # JSON output contract for Confluence subagent
        │   └── jira-response.schema.json         # JSON output contract for Jira subagent
        └── decisions/
            └── ADR-001-architecture.md           # Architecture Decision Record #1
```

---

## Acceptance Criteria Log

Each acceptance criterion from the project brief, with its implementation mapping.

| # | Requirement | Status | Implementation |
|---|---|---|---|
| AC-1 | Validation flow for credentials, directories, and dependencies | Implemented | `scripts/validate.sh` — checks env vars, makes live API calls, verifies directory structure, checks Node.js availability |
| AC-2 | Orchestrator uses MCP tools directly for Atlassian integrations | Implemented | `AGENTS.md` + `opencode.json` with MCP tool namespace configuration (`confluence_datacenter_*`, `jira_datacenter_*`) |
| AC-3 | Deterministic workflows — operations finish as expected | Implemented | Structured MCP tool responses + clear error handling patterns |
| AC-4 | Deterministic workflows — operations finish as expected | Implemented | Structured MCP tool responses + clear error handling patterns |
| AC-5 | OpenCode as the main tool | Implemented | All config lives in `.opencode/`; standard OpenCode conventions throughout |
| AC-6 | GitHub Copilot enterprise licenses | Implemented | Model set to `github-copilot/claude-sonnet-4.5` in `opencode.json` |
| AC-7 | Structured knowledge in dedicated folder, not monolithic AGENTS.md | Implemented | `.opencode/docs/` contains modular markdown per agent, JSON contracts, and ADRs; loaded via `instructions` glob in `opencode.json` |

---

## Decision Log

All significant technical decisions made during the design phase, with rationale.

---

### DEC-001 — Orchestrator is the Primary Build Agent

**Decision**: The orchestrator is OpenCode's built-in primary Build agent, configured via `AGENTS.md` and `opencode.json`. It uses MCP tools directly.

**Rationale**: The build agent has full MCP tool access and can directly call Atlassian APIs through MCP servers. A separate orchestration layer adds complexity without value.

**Trade-off**: The orchestrator's context accumulates across operations in a session. This is intentional for cross-tool knowledge sharing.

---

### DEC-002 — Direct MCP Tool Usage (Not Subagent Delegation)

**Decision**: The orchestrator calls MCP tools directly rather than delegating through subagents.

**Rationale**: MCP tools provide clean, structured interfaces. Adding a subagent delegation layer creates unnecessary complexity and context overhead.

**Trade-off**: No isolated child sessions for Atlassian operations. All operations run in the orchestrator's context, which simplifies debugging and reduces latency.

---

### DEC-003 — Atlassian Integration via `mcp-atlassian` Community MCP

**Decision**: Use the community `mcp-atlassian` MCP server (via `npx mcp-atlassian`) rather than building a custom MCP.

**Rationale**: The community server covers the Atlassian Cloud REST API surface for both Confluence and Jira. Building a custom MCP would require significant engineering effort for no differential value at this stage.

**Trade-off**: Dependency on a community package. Mitigated by pinning to a version in `package.json` once the project matures, and by the fact that the MCP tool interface is stable regardless of the underlying implementation.

**Revisit condition**: If the community MCP lacks a required tool or has reliability issues, migrate to a custom MCP following the same pattern.

---

### DEC-004 — Determinism via JSON Output Contracts + Low Temperature

**Decision**: Subagent determinism is enforced at two levels:
1. **Structural**: Each subagent's system prompt requires the response to be a valid JSON object matching a specific schema file.
2. **Statistical**: `temperature: 0.1` on all subagents reduces response variability.

**Rationale**: True determinism is impossible with LLMs, but the contract approach provides determinism at the *interface boundary* — the orchestrator always receives a predictably structured response it can parse and validate programmatically. Internal reasoning variability is contained inside the child session.

**Trade-off**: Subagents lose the ability to return free-form explanations in their primary response. Any narrative content must be embedded inside the JSON schema (e.g., a `summary` field).

---

### DEC-005 — Skills for Domain Workflow Knowledge

**Decision**: Atlassian-specific workflow knowledge (e.g., how to traverse a Confluence space, how to decompose a Jira epic) is stored as loadable Skills rather than embedded in agent system prompts.

**Rationale**: Skills are loaded on demand via the `skill` tool. This keeps the agent's base context lean and avoids bloating every invocation with knowledge that may only be needed for specific task types.

**Trade-off**: The agent must decide when to load a skill. For edge cases where it fails to load the relevant skill, the agent may produce lower-quality output. Mitigated by clear `description` fields in `SKILL.md` that make skill applicability obvious.

---

### DEC-006 — MCP Tools Scoped Per Agent via Global Deny + Per-Agent Allow

**Decision**: The `mcp-atlassian` MCP server is registered globally but all its tools are denied globally (`"atlassian_*": false`). Individual agents enable only the tool namespaces they need.

**Rationale**: The Confluence subagent should never have access to Jira mutating tools, and vice versa. Scoping at the tool level enforces the principle of least privilege and prevents cross-contamination.

**Implementation**:
```json
"tools": { "atlassian_*": false },
"agent": {
  "confluence": { "tools": { "atlassian_confluence_*": true } },
  "jira":       { "tools": { "atlassian_jira_*": true } }
}
```

---

### DEC-007 — No Database in Phase 1

**Decision**: No database is used in Phase 1. Credentials are stored in `.env` (gitignored), and all outputs are ephemeral within the session.

**Rationale**: The current use cases (read/extract/summarize from Confluence and Jira) do not require persistent state between sessions.

**Revisit condition**: Phase 2 will evaluate an anti-amnesia strategy. Candidates include SQLite for local session memory or a vector database for semantic retrieval of past agent outputs and decisions.

---

### DEC-008 — Structured Knowledge in `.opencode/docs/` Loaded via `instructions` Glob

**Decision**: All important knowledge (agent capabilities, output contracts, decision records) lives in `.opencode/docs/`. The `opencode.json` `instructions` field loads this entire directory into every session.

**Rationale**: A monolithic `AGENTS.md` becomes unmanageable as the number of agents grows. A modular folder structure allows each agent/workflow/contract to have its own file, versioned independently, reviewed in isolation, and easily cross-referenced.

**Structure**:
```
.opencode/docs/
  README.md           ← always loaded, provides the index
  agents/             ← one file per subagent
  contracts/          ← one schema per subagent output
  decisions/          ← ADR-NNN-title.md
```

---

### DEC-009 — GitHub Copilot Model: `claude-sonnet-4.5` for All Agents

**Decision**: Use `github-copilot/claude-sonnet-4.5` for both the orchestrator and subagents.

**Rationale**: The enterprise holds GitHub Copilot licenses. Using a single capable model for all agents simplifies configuration and avoids quality inconsistencies at agent boundaries. Subagent cost is controlled via `temperature: 0.1` and strict output schemas rather than by downgrading the model.

**Note**: Run `opencode models` to verify the exact model ID available on your Copilot license before deploying.

---

### DEC-010 — Validation as a Standalone Bash Script

**Decision**: `scripts/validate.sh` is a plain bash script, not an OpenCode slash command or CI gate.

**Rationale**: A standalone script has zero dependency on OpenCode itself, making it runnable during onboarding, in CI pipelines, or in environments where OpenCode is not yet installed. It also avoids circular dependency (you need credentials to run OpenCode, but you want to validate credentials before running OpenCode).

---

## Getting Started

### Prerequisites

| Requirement | Version | Purpose |
|---|---|---|
| [OpenCode](https://opencode.ai) | Latest | Primary agent interface |
| Node.js | ≥ 18 | Required to run `mcp-atlassian` via `npx` |
| `curl` | Any modern | Used by `validate.sh` for API reachability checks |
| GitHub Copilot license | Active | LLM provider for all agents |
| Atlassian Cloud account | Active | Confluence + Jira access |

### Environment Setup

1. Copy the environment template:
   ```bash
   cp .env.example .env
   ```

2. Fill in your values in `.env`:
   ```bash
   ATLASSIAN_URL=https://your-org.atlassian.net
   ATLASSIAN_EMAIL=your.email@company.com
   ATLASSIAN_API_TOKEN=your_api_token_here
   ```

   To generate an Atlassian API token:
   - Go to https://id.atlassian.com/manage-profile/security/api-tokens
   - Click **Create API token**
   - Copy and paste the value into `.env`

3. Ensure `.env` is in `.gitignore` (it is by default in this template).

### Validation

Run the pre-flight validation script before your first session:

```bash
bash scripts/validate.sh
```

The script checks:
- All required environment variables are set and non-empty
- Confluence Cloud API is reachable and the credentials are valid
- Jira Cloud API is reachable and the credentials are valid
- All required `.opencode/` directories exist
- Node.js is available for `npx mcp-atlassian`

**Example output (success):**
```
[✓] ATLASSIAN_URL is set
[✓] ATLASSIAN_EMAIL is set
[✓] ATLASSIAN_API_TOKEN is set
[✓] Confluence API reachable (HTTP 200)
[✓] Jira API reachable (HTTP 200)
[✓] .opencode/agents/ directory exists
[✓] .opencode/skills/ directory exists
[✓] .opencode/docs/ directory exists
[✓] Node.js available (v20.x.x)
[✓] All checks passed. Ready to run OpenCode.
```

**Example output (failure):**
```
[✗] ATLASSIAN_API_TOKEN is not set
    → Add it to your .env file. See .env.example for reference.
[!] Validation failed. Fix the above errors before running OpenCode.
```

### Running OpenCode

Once validation passes:

```bash
opencode
```

OpenCode will load all agent configuration from `.opencode/`, including the MCP server, subagent definitions, skills, and structured docs.

---

## Agents

### Orchestrator (Primary Build Agent)

The orchestrator is OpenCode's default primary Build agent. It is not a custom agent — it inherits all of OpenCode's built-in capabilities.

**What it knows:**
- All available subagents (via `AGENTS.md` and subagent `description` fields)
- When to invoke each subagent (routing rules in `AGENTS.md`)
- How to validate subagent outputs (JSON contracts in `.opencode/docs/contracts/`)
- Project structure and conventions (loaded from `.opencode/docs/` via `instructions` glob)

**Invoking subagents:**
The orchestrator spawns subagents automatically based on task context. You can also invoke them manually:
```
@confluence search for pages about quarterly planning in the Engineering space
```
```
@jira get all open critical bugs in the PLATFORM project assigned to me
```

### Confluence Subagent

**File**: `.opencode/agents/confluence.md`

| Property | Value |
|---|---|
| Mode | `subagent` |
| Model | `github-copilot/claude-sonnet-4.5` |
| Temperature | `0.1` |
| MCP tools | `atlassian_confluence_*` only |
| Edit permission | `deny` |
| Bash permission | `deny` |
| Output format | JSON (see `.opencode/docs/contracts/confluence-response.schema.json`) |

**Capabilities:**
- Search Confluence spaces and pages by keyword, label, or CQL query
- Extract and summarize page content
- List child pages and space hierarchies
- Retrieve page metadata (author, last updated, version)

**When to invoke:**
- User asks about documentation, runbooks, architecture decisions, or onboarding guides
- User needs to find information across a Confluence space
- User needs a summary of a specific Confluence page or space

### Jira Subagent

**File**: `.opencode/agents/jira.md`

| Property | Value |
|---|---|
| Mode | `subagent` |
| Model | `github-copilot/claude-sonnet-4.5` |
| Temperature | `0.1` |
| MCP tools | `atlassian_jira_*` only |
| Edit permission | `deny` |
| Bash permission | `deny` |
| Output format | JSON (see `.opencode/docs/contracts/jira-response.schema.json`) |

**Capabilities:**
- Search issues using JQL queries
- Retrieve issue details, comments, and linked issues
- List epics, sprints, and backlog items for a project
- Get assignee, status, priority, and label information

**When to invoke:**
- User asks about tickets, epics, sprints, or project status
- User needs to aggregate Jira data for reporting
- User needs to find issues by criteria (assignee, label, status, sprint)

---

## Skills

Skills are loaded **on demand** by subagents when the task requires specific workflow knowledge. They are not loaded for every invocation — only when relevant.

### `confluence-ops`

**File**: `.opencode/skills/confluence-ops/SKILL.md`

Covers:
- Traversing a Confluence space hierarchy recursively
- Extracting structured content from pages with tables or code blocks
- CQL query patterns for common search scenarios
- Handling pagination in Confluence API responses

### `jira-ops`

**File**: `.opencode/skills/jira-ops/SKILL.md`

Covers:
- Decomposing an epic into its child stories and tasks
- Building JQL queries for sprint analysis and reporting
- Handling Jira pagination and large result sets
- Mapping Jira statuses to workflow stages

---

## Output Contracts

All subagents return **structured JSON** matching their schema contract. This is the determinism backbone of the system.

### Why contracts matter

Without contracts, subagent output is free-form text. The orchestrator would need to parse natural language to extract structured data — introducing non-determinism at the boundary.

With contracts, the orchestrator can:
```javascript
const result = JSON.parse(subagentOutput);
if (result.status !== "success") {
  // handle error deterministically
}
result.data.pages.forEach(page => { ... });
```

### Contract files

| File | Used by |
|---|---|
| `.opencode/docs/contracts/confluence-response.schema.json` | Confluence subagent |
| `.opencode/docs/contracts/jira-response.schema.json` | Jira subagent |

See each schema file for the full contract definition.

---

## MCP Integration

The `mcp-atlassian` server is started automatically by OpenCode when a session begins (via `npx`). No manual startup required.

**Configuration location**: `.opencode/opencode.json` under `mcp.atlassian`

**Authentication**: Basic auth using `ATLASSIAN_EMAIL` + `ATLASSIAN_API_TOKEN` against `ATLASSIAN_URL`.

**Tool namespacing**: All tools from this MCP are prefixed `atlassian_`. They are split into two groups:
- `atlassian_confluence_*` — available only to the Confluence subagent
- `atlassian_jira_*` — available only to the Jira subagent

The orchestrator and other agents cannot call Atlassian tools directly. All Atlassian access goes through the relevant subagent.

---

## Extending the System

Adding a new integration follows a fixed 5-step pattern:

### Step 1 — Add or configure the MCP server

In `.opencode/opencode.json`, add the new MCP under `mcp` and deny its tools globally:
```json
"mcp": {
  "new-service": { "type": "local", "command": ["npx", "-y", "mcp-new-service"], ... }
},
"tools": {
  "new-service_*": false
}
```

### Step 2 — Create the subagent definition

Create `.opencode/agents/new-service.md` following the same structure as `confluence.md` or `jira.md`. Key fields:
- `mode: subagent`
- `temperature: 0.1`
- `description`: what it does and when to use it (this is what the orchestrator reads)
- Tool grants for only the new MCP's tools

### Step 3 — Create the output contract

Add `.opencode/docs/contracts/new-service-response.schema.json` following the same structure as the existing schemas.

### Step 4 — Create the skill

Add `.opencode/skills/new-service-ops/SKILL.md` with domain-specific workflow recipes.

### Step 5 — Create the agent knowledge doc

Add `.opencode/docs/agents/new-service.md` documenting capabilities, when to invoke, and output contract reference.

The orchestrator will discover the new subagent automatically on the next session (descriptions are loaded from the agent files).

---

## Roadmap

### Phase 1 (Current)
- [x] Architecture and decision documentation
- [ ] Validation script (`scripts/validate.sh`)
- [ ] MCP configuration (`opencode.json`)
- [ ] Confluence subagent
- [ ] Jira subagent
- [ ] Confluence workflows skill
- [ ] Jira workflows skill
- [ ] Output contracts (JSON schemas)
- [ ] Structured knowledge store (`.opencode/docs/`)

### Phase 2 (Planned)
- [ ] Anti-amnesia strategy — persistent session memory (SQLite or vector DB TBD)
- [ ] Outlook integration subagent
- [ ] Cross-agent workflow composition (e.g., Jira epic → Confluence spec → PR)
- [ ] CI integration for `validate.sh`
- [ ] Shared skill library for common enterprise workflows

---

## Contributing

This repository is a living template. When making significant changes:

1. Add an ADR in `.opencode/docs/decisions/ADR-NNN-title.md`
2. Update the relevant agent knowledge doc in `.opencode/docs/agents/`
3. Update this README if the architecture changes
4. Run `bash scripts/validate.sh` before committing

---

*Built with [OpenCode](https://opencode.ai) · Powered by GitHub Copilot · Maintained by the Enterprise Engineering team*
