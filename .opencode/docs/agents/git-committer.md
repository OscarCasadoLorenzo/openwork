# Git Committer Subagent — Agent Knowledge

## Identity

- **Agent ID**: `git-committer`
- **File**: `.opencode/agents/git-committer.md`
- **Mode**: `subagent`
- **Model**: `github-copilot/claude-sonnet-4.5`
- **Temperature**: `0.2`

---

## Purpose

The Git Committer subagent is an autonomous assistant specialized in analyzing Git repository changes and generating clean, structured commit sequences that follow Conventional Commits specification with GitFlow prefix extraction.

The orchestrator can delegate to this agent when the user requests assistance with committing changes, but this agent is primarily designed to be invoked directly via `@git-committer` from the OpenCode terminal.

---

## Capabilities

| Operation | Description |
|---|---|
| `detect_changes` | Compare local repository against remote tracking branch |
| `group_changes` | Group related file modifications into logical commit units |
| `extract_prefix` | Extract project identifier from GitFlow branch names |
| `generate_commits` | Create Conventional Commits with detailed descriptions and context |
| `execute_commits` | Stage and commit changes atomically |

---

## When to Invoke

Invoke the Git Committer subagent when:
- The user wants to commit multiple changes in a structured way
- Changes need to be grouped by functionality or objective
- Commits must follow Conventional Commits + GitFlow prefix patterns
- The user wants atomic, semantic commits with context explanations

Do NOT invoke for:
- Simple single-file commits (handle directly)
- Commits to files containing credentials
- Operations that require pushing to remote (unless explicitly requested)

---

## Permissions Granted

- `bash`: `allow` — Required for git commands
- `read`: `allow` — Required to read changed files for grouping analysis
- `glob`: `allow` — Required to identify file patterns
- `grep`: `allow` — Required to analyze file contents
- `edit`: `deny` — Agent only commits, does not modify files
- `task`: `deny` — Agent does not spawn subagents
- `webfetch`: `deny` — Agent works entirely locally

---

## Branch & Prefix Extraction

The agent extracts project prefixes from GitFlow branch names:

| Branch Pattern | Extracted Prefix |
|---|---|
| `feature/SPM-5` | `SPM-5` |
| `bugfix/PLAT-123` | `PLAT-123` |
| `hotfix/API-9` | `API-9` |

All commits are prefixed with: `<PREFIX> <type>: <description>`

Example: `SPM-5 feat: add user authentication middleware`

---

## Commit Structure

Each commit follows this structure:

```
<PREFIX> <type>: <concise summary>

- Bullet point describing what changed
- Another bullet describing modifications
- Detailed list of all changes

Context:
A short paragraph explaining why these changes were made, what problem
they solve, or what functionality they enable.
```

Commit types follow Conventional Commits v1.0.0:
- `feat` — new feature
- `fix` — bug fix
- `refactor` — code restructuring without behavior change
- `docs` — documentation only
- `test` — test additions or modifications
- `chore` — maintenance tasks
- `perf` — performance improvements
- `style` — formatting changes
- `ci` — CI/CD pipeline changes

---

## Workflow

1. **Detect Changes**: Run `git status` and `git diff` to identify all modified/added/deleted files
2. **Extract Branch Prefix**: Parse current branch name to get project identifier
3. **Group Changes**: Analyze file relationships and group by functionality
4. **Generate Commit Messages**: Create structured messages with descriptions and context
5. **Execute Commits**: Stage each group and commit atomically
6. **Verify**: Run `git status` to confirm clean working tree

---

## Output Format

The agent provides a summary of all commits created:

```
Detected 3 groups of changes.
Created commits:

1) SPM-5 feat: implement user authentication
   - Added JWT middleware
   - Created auth service with token validation
   - Added login/logout endpoints
   
   Context: Implements secure authentication flow required for
   protecting admin routes and user-specific data access.

2) SPM-5 test: add authentication integration tests
   - Added test suite for auth endpoints
   - Created mock user fixtures
   
   Context: Ensures authentication flow works correctly across
   different user roles and edge cases.

3) SPM-5 docs: update API documentation
   - Added authentication section to API docs
   - Documented new auth endpoints
   
   Context: Provides clear guidance for frontend developers
   integrating with the new authentication system.

Working tree clean. All commits successfully applied.
```

---

## Constraints

- **No credential commits**: Never stage or commit `.env`, `credentials.json`, or similar files
- **No force operations**: Never use `--amend` unless HEAD commit is from current session AND not pushed
- **No hook skipping**: Never use `--no-verify` unless explicitly requested
- **No auto-push**: Never push to remote unless user explicitly requests it
- **Branch validation**: Verify branch follows GitFlow naming; ask user if not

---

## Usage Example

```bash
# User invokes the agent directly from OpenCode terminal
@git-committer

# Or orchestrator delegates
Task: "Analyze my changes and create structured commits following our GitFlow standards"
```

---

## Integration Notes

This agent is **not** part of the core orchestrator's Atlassian delegation workflow. It is an independent utility agent that can be invoked on-demand when Git commit assistance is needed.

The orchestrator does not need to know about this agent's internal workflow details. It only needs to know it exists and can be delegated to when commit structuring is requested.
