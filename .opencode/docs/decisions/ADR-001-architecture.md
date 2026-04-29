# ADR-001 — Multiagent System Architecture

**Status**: Accepted
**Date**: 2026-04-28
**Authors**: Oscar Casado, OpenCode AI architect
**Deciders**: Enterprise Engineering team

---

## Context

The enterprise needs a scalable template for coordinating multiagent AI workflows using OpenCode. The initial integrations are Confluence Cloud and Jira Cloud, with additional integrations (Outlook, Slack, etc.) planned for future phases.

The design must satisfy the following acceptance criteria:

1. Validation flow for credentials, directories, and runtime dependencies
2. Orchestrator agent aware of available subagents and their capabilities
3. Subagent context encapsulated and isolated from the orchestrator
4. Deterministic workflows with verifiable operation outcomes
5. OpenCode as the primary tool
6. Compatible with GitHub Copilot enterprise licenses
7. Structured knowledge stored in a dedicated folder — not a monolithic `AGENTS.md`

---

## Decisions

### 1. Orchestrator = Primary Build Agent

The built-in OpenCode Build agent serves as the orchestrator. No custom orchestrator agent is defined.

**Why**: A custom orchestrator would add configuration overhead without providing additional capability. The Build agent already has full tool access, supports custom system prompts via `AGENTS.md`, and can invoke any subagent via the Task tool.

### 2. Subagents as Markdown Agent Files

Each specialised integration is implemented as a `.opencode/agents/<name>.md` file using OpenCode's native agent configuration format.

**Why**: This is the idiomatic OpenCode approach. Markdown agent files support all required options (model, temperature, permissions, system prompt) and are version-controlled alongside the rest of the configuration.

### 3. Context Isolation via Native Child Sessions

OpenCode's Task tool spawns each subagent in an isolated child session. The orchestrator only receives the subagent's final output.

**Why**: This provides clean context boundaries for free, with no custom infrastructure. The orchestrator's context is never polluted by the subagent's intermediate reasoning.

### 4. Atlassian Integration via `mcp-atlassian` MCP Server

The community `mcp-atlassian` package (run via `npx`) provides the Atlassian Cloud API surface for both Confluence and Jira.

**Why**: Avoids building a custom MCP server. The community package covers all required read operations. Credentials are injected via environment variables, not hardcoded.

### 5. MCP Tools Scoped Per Agent (Least Privilege)

Atlassian MCP tools are denied globally and enabled only for the agent that needs them. The Confluence agent cannot access Jira tools and vice versa.

**Why**: Enforces the principle of least privilege. Prevents accidental cross-domain calls and makes it impossible for the orchestrator to bypass the delegation model.

### 6. Determinism via JSON Output Contracts + Low Temperature

All subagents output a single JSON object matching a versioned JSON Schema. Temperature is set to `0.1` on all subagents.

**Why**: True LLM determinism is not achievable, but interface-level determinism is. A typed contract ensures the orchestrator always receives a predictably structured response it can parse programmatically. The `status`, `operation`, and `error` fields provide machine-readable outcome metadata.

### 7. Skills for Domain Workflow Knowledge

Atlassian-specific workflow knowledge (CQL patterns, JQL construction, pagination loops, epic decomposition) is stored as loadable Skills in `.opencode/skills/`.

**Why**: Keeps the agent's base system prompt lean. Skills are loaded on demand only when the task requires them, avoiding unnecessary context bloat on every invocation.

### 8. Structured Knowledge in `.opencode/docs/`

All important data — agent capabilities, output contracts, architecture decisions — lives in `.opencode/docs/`. It is loaded automatically via the `instructions` glob in `opencode.json`.

**Why**: A monolithic `AGENTS.md` becomes unmaintainable as the system grows. A modular folder structure allows independent versioning, code review, and cross-referencing of each concern.

### 9. Model: `github-copilot/claude-sonnet-4.5`

All agents use the same model, available via the enterprise's GitHub Copilot licenses.

**Why**: Using a single capable model simplifies configuration and avoids quality inconsistencies at agent boundaries. Cost is controlled by low temperature and strict output schemas, not by using cheaper models for subagents.

### 10. Validation as a Standalone Bash Script

Environment and connectivity validation is implemented in `scripts/validate.sh`, a plain bash script with no dependency on OpenCode.

**Why**: The validation must run before OpenCode is started (to verify credentials that OpenCode needs). An OpenCode slash command would require OpenCode to already be running, creating a circular dependency.

---

## Consequences

**Positive**:
- Clear, predictable delegation model — the orchestrator always routes Atlassian work to the correct subagent
- Verifiable outputs — every subagent response has a typed contract the orchestrator can assert against
- Extensible — adding a new integration follows a documented 5-step pattern
- Maintainable — each concern (agent, contract, skill, decision) has its own versioned file

**Negative / Trade-offs**:
- Subagents cannot return free-form explanations — all narrative must be embedded in the JSON schema's `summary` field
- The skill-based knowledge model requires the agent to make a correct decision about when to load a skill — if it fails to load the relevant skill, output quality may degrade for complex tasks
- `mcp-atlassian` is a community dependency — if it becomes unmaintained, a migration to a custom MCP will be required (DEC-003 revisit condition)

---

## Future Considerations

- **Phase 2**: Anti-amnesia strategy — persistent session memory across OpenCode sessions. Candidates: SQLite (local, simple), vector DB (semantic retrieval of past decisions and agent outputs).
- **Outlook subagent**: Same pattern as Confluence/Jira. Requires an `mcp-outlook` or Microsoft Graph MCP server.
- **Write operations**: Phase 1 is read-only by design. Phase 2 may introduce controlled write operations (e.g., creating a Jira issue from a Confluence decision). This will require explicit user confirmation gates in the orchestrator.
- **Cross-agent workflows**: Composing results from multiple subagents (e.g., Jira epic → Confluence spec) will require a workflow composition pattern not yet defined. This will be addressed as ADR-002.
