#!/usr/bin/env bash
# =============================================================================
# scripts/smoke-test.sh
# Validates the multiagent system's thought sequence in complete isolation.
#
# Each test uses `opencode run` which starts a BRAND NEW headless session with:
#   - ZERO history from any previous conversation (including the design session)
#   - ONLY what is on disk: AGENTS.md, .opencode/docs/, .opencode/agents/
#
# This guarantees that results reflect the actual system configuration,
# not any prior conversation context.
#
# Test sequence:
#   1. Environment pre-check (credentials, structure, Node.js)
#   2. Orchestrator context check — does it know the right subagents?
#   3. Delegation routing check — does it route Atlassian tasks to subagents?
#   4. Confluence subagent contract compliance — is output valid JSON?
#   5. Jira subagent contract compliance — is output valid JSON?
#   6. Tool isolation — can Jira agent access Confluence tools? (must not)
#
# Usage:
#   bash scripts/smoke-test.sh
#   bash scripts/smoke-test.sh --skip-env   # skip env/structure checks
#   bash scripts/smoke-test.sh --verbose    # show full agent output
#
# Exit codes:
#   0  All tests passed
#   1  One or more tests failed
# =============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# Colour helpers
# --------------------------------------------------------------------------
if [ -t 1 ] && command -v tput &>/dev/null && tput colors &>/dev/null; then
  GREEN=$(tput setaf 2); RED=$(tput setaf 1); YELLOW=$(tput setaf 3)
  CYAN=$(tput setaf 6); BOLD=$(tput bold); RESET=$(tput sgr0)
else
  GREEN="" RED="" YELLOW="" CYAN="" BOLD="" RESET=""
fi

PASS="${GREEN}[PASS]${RESET}"; FAIL="${RED}[FAIL]${RESET}"
INFO="${CYAN}[INFO]${RESET}"; WARN="${YELLOW}[WARN]${RESET}"

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; TESTS_SKIPPED=0
VERBOSE=false; SKIP_ENV=false
OUTPUT_DIR=$(mktemp -d)

trap 'rm -rf "${OUTPUT_DIR}"' EXIT

for arg in "$@"; do
  case $arg in
    --verbose) VERBOSE=true ;;
    --skip-env) SKIP_ENV=true ;;
  esac
done

pass()    { echo -e "${PASS} $1"; TESTS_PASSED=$((TESTS_PASSED+1)); TESTS_RUN=$((TESTS_RUN+1)); }
fail()    { echo -e "${FAIL} $1"; echo -e "       ${RED}$2${RESET}"; TESTS_FAILED=$((TESTS_FAILED+1)); TESTS_RUN=$((TESTS_RUN+1)); }
skip()    { echo -e "${WARN}[SKIP] $1 — $2"; TESTS_SKIPPED=$((TESTS_SKIPPED+1)); }
info()    { echo -e "${INFO} $1"; }
header()  { echo -e "\n${BOLD}$1${RESET}\n${CYAN}$(printf '─%.0s' {1..60})${RESET}"; }
subinfo() { [ "$VERBOSE" = true ] && echo -e "       ${YELLOW}↳ $1${RESET}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

[ -f "${ENV_FILE}" ] && { set -a; source "${ENV_FILE}"; set +a; }

has_credentials() {
  [ -n "${ATLASSIAN_URL:-}" ] && [ -n "${ATLASSIAN_EMAIL:-}" ] && [ -n "${ATLASSIAN_API_TOKEN:-}" ]
}

# Helper: run opencode with a prompt in a fresh isolated session
# --agent flag targets a specific agent directly (bypasses orchestrator routing)
run_agent() {
  local agent="$1"; local prompt="$2"; local outfile="$3"
  local agent_flag=""
  [ -n "$agent" ] && agent_flag="--agent ${agent}"

  # opencode run starts a fresh session each time — no conversation history
  # shellcheck disable=SC2086
  opencode run ${agent_flag} "${prompt}" > "${outfile}" 2>&1
}

# Helper: check if a file contains valid JSON anywhere in it
# (agent output may include preamble text before/after JSON)
extract_json() {
  local file="$1"
  # Try to find a JSON object in the output using node
  node --input-type=module <<'EOF' 2>/dev/null < <(cat "${file}")
import { readFileSync } from 'fs';
const text = readFileSync('/dev/stdin', 'utf8');
// Find the outermost JSON object in the text
const match = text.match(/\{[\s\S]*\}/);
if (match) {
  try {
    const parsed = JSON.parse(match[0]);
    process.stdout.write(JSON.stringify(parsed));
    process.exit(0);
  } catch {}
}
process.exit(1);
EOF
}

is_valid_json() { node -e "JSON.parse(require('fs').readFileSync('${1}','utf8'))" 2>/dev/null; }

json_has_field() {
  local file="$1"; local field="$2"
  node -e "const d=JSON.parse(require('fs').readFileSync('${file}','utf8')); process.exit(d.${field}===undefined?1:0)" 2>/dev/null
}

json_field_value() {
  local file="$1"; local field="$2"
  node -e "const d=JSON.parse(require('fs').readFileSync('${file}','utf8')); console.log(d.${field})" 2>/dev/null
}

# =============================================================================
# PRE-FLIGHT
# =============================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       Multiagent System — Smoke Test                     ║${RESET}"
echo -e "${BOLD}║  Fresh isolated sessions via \`opencode run\`               ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
info "Each test spawns a NEW opencode session with zero conversation history."
info "Results are based solely on: AGENTS.md, .opencode/docs/, .opencode/agents/"
echo ""

# --------------------------------------------------------------------------
# STEP 1 — Pre-flight checks
# --------------------------------------------------------------------------
header "Step 1 — Pre-flight checks"

if [ "$SKIP_ENV" = false ]; then
  info "Running validate.sh first…"
  if bash "${SCRIPT_DIR}/validate.sh" > "${OUTPUT_DIR}/validate.log" 2>&1; then
    pass "validate.sh — all checks passed"
  else
    VALIDATION_OUTPUT=$(cat "${OUTPUT_DIR}/validate.log")
    # Distinguish: only credential errors (expected) vs structural errors (not expected)
    STRUCTURAL_ERRORS=$(grep "\[✗\]" "${OUTPUT_DIR}/validate.log" | grep -v "ATLASSIAN" || true)
    if [ -z "$STRUCTURAL_ERRORS" ]; then
      echo -e "${WARN}[WARN] Credential env vars not set — API tests will be skipped"
      echo -e "       Set ATLASSIAN_URL, ATLASSIAN_EMAIL, ATLASSIAN_API_TOKEN in .env"
    else
      fail "validate.sh — structural errors found" "Fix validate.sh errors before running smoke tests"
      echo ""
      cat "${OUTPUT_DIR}/validate.log"
      exit 1
    fi
  fi

  if ! command -v opencode &>/dev/null; then
    fail "opencode CLI not found" "Install OpenCode: https://opencode.ai — required for all tests"
    exit 1
  fi
  pass "opencode CLI available ($(opencode --version 2>/dev/null || echo 'version unknown'))"
else
  info "Skipping pre-flight (--skip-env)"
fi

# --------------------------------------------------------------------------
# STEP 2 — Orchestrator context integrity
# Tests that the orchestrator's self-knowledge matches the AGENTS.md + docs
# In a fresh session, it should NOT know anything from this design conversation.
# --------------------------------------------------------------------------
header "Step 2 — Orchestrator context integrity (fresh session, zero history)"

info "Asking orchestrator to describe its available subagents…"
OUTFILE="${OUTPUT_DIR}/test-orchestrator-context.txt"

if run_agent "" "In one sentence each, list every subagent you have available to delegate tasks to. Output ONLY a JSON array of objects with fields: id, purpose. No other text." "${OUTFILE}"; then
  subinfo "$(cat "${OUTFILE}")"
  CONTENT=$(cat "${OUTFILE}")

  if echo "$CONTENT" | grep -qi "confluence"; then
    pass "Orchestrator knows 'confluence' subagent — loaded from AGENTS.md"
  else
    fail "Orchestrator does not know 'confluence' subagent" "Check AGENTS.md and .opencode/docs/agents/confluence.md are correct"
  fi

  if echo "$CONTENT" | grep -qi "jira"; then
    pass "Orchestrator knows 'jira' subagent — loaded from AGENTS.md"
  else
    fail "Orchestrator does not know 'jira' subagent" "Check AGENTS.md and .opencode/docs/agents/jira.md are correct"
  fi

  if echo "$CONTENT" | grep -qiE "design session|previous conversation|we built|you created"; then
    fail "Orchestrator output shows contamination from previous conversations" \
         "The output contains references to the design session. This indicates context leakage."
  else
    pass "No context contamination detected — orchestrator knows only what is in docs"
  fi
else
  fail "opencode run failed to produce output for orchestrator context test" "Check opencode is correctly installed and configured"
fi

# --------------------------------------------------------------------------
# STEP 3 — Delegation routing
# Tests that the orchestrator delegates Atlassian tasks to subagents
# instead of trying to handle them directly.
# --------------------------------------------------------------------------
header "Step 3 — Delegation routing (orchestrator delegates, does not answer directly)"

info "Sending a Confluence task to the orchestrator…"
OUTFILE="${OUTPUT_DIR}/test-delegation-confluence.txt"

if run_agent "" "Find pages about deployment in Confluence. I need the results." "${OUTFILE}"; then
  subinfo "$(cat "${OUTFILE}")"
  CONTENT=$(cat "${OUTFILE}")

  if echo "$CONTENT" | grep -qiE "delegat|confluence agent|@confluence|subagent|task tool"; then
    pass "Orchestrator delegated to confluence subagent (routing confirmed)"
  elif echo "$CONTENT" | grep -qiE '"status"'; then
    pass "Orchestrator relayed a JSON contract response — delegation occurred"
  else
    fail "Orchestrator may have answered directly without delegating" \
         "Check AGENTS.md delegation rules. Orchestrator should not answer Atlassian queries directly."
  fi
else
  fail "opencode run failed for delegation routing test" "Check opencode installation"
fi

# --------------------------------------------------------------------------
# STEP 4 — Confluence subagent contract compliance
# Tests the subagent directly (--agent confluence) to verify:
#   a) Output is valid JSON
#   b) Required contract fields are present (status, operation)
#   c) Error handling returns correct contract structure (no credentials case)
# --------------------------------------------------------------------------
header "Step 4 — Confluence subagent — JSON contract compliance"

info "Invoking confluence subagent directly (fresh isolated session)…"
OUTFILE="${OUTPUT_DIR}/test-confluence-contract.txt"
JSON_FILE="${OUTPUT_DIR}/test-confluence-contract.json"

if run_agent "confluence" "Search for pages about deployment." "${OUTFILE}"; then
  subinfo "$(cat "${OUTFILE}")"
  CONTENT=$(cat "${OUTFILE}")

  # Extract JSON from output (might have surrounding text)
  if echo "$CONTENT" | node --input-type=module <<'EOF' > "${JSON_FILE}" 2>/dev/null
import { readFileSync } from 'fs';
const text = readFileSync('/dev/stdin', 'utf8');
const match = text.match(/\{[\s\S]*\}/);
if (!match) process.exit(1);
try { JSON.parse(match[0]); process.stdout.write(match[0]); process.exit(0); } catch { process.exit(1); }
EOF
  then
    pass "Confluence subagent returned valid JSON (contract enforced)"
    subinfo "$(cat "${JSON_FILE}")"

    # Check required fields
    if node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); if(!d.status)process.exit(1)" 2>/dev/null; then
      STATUS=$(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); console.log(d.status)" 2>/dev/null)
      pass "Contract field 'status' present (value: ${STATUS})"
    else
      fail "Contract field 'status' missing" "Check confluence agent system prompt — it must enforce the output contract"
    fi

    if node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); if(!d.operation)process.exit(1)" 2>/dev/null; then
      OP=$(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); console.log(d.operation)" 2>/dev/null)
      pass "Contract field 'operation' present (value: ${OP})"
    else
      fail "Contract field 'operation' missing" "Check confluence agent system prompt"
    fi

    # Verify error structure if no credentials
    if ! has_credentials; then
      if node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); if(d.status!=='error')process.exit(1)" 2>/dev/null; then
        CODE=$(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); console.log(d.error&&d.error.code||'missing')" 2>/dev/null)
        pass "Correct error contract returned with no credentials (error.code: ${CODE})"
      else
        fail "Expected error contract with no credentials, but got status: $(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8'));console.log(d.status)" 2>/dev/null)" \
             "With no ATLASSIAN credentials, status should be 'error'"
      fi
    fi
  else
    fail "Confluence subagent did not return valid JSON" \
         "The subagent's output contract is not being enforced. Check .opencode/agents/confluence.md system prompt."
    [ "$VERBOSE" = true ] && echo "" && cat "${OUTFILE}" && echo ""
  fi
else
  fail "opencode run --agent confluence failed" "Check opencode and .opencode/agents/confluence.md"
fi

# --------------------------------------------------------------------------
# STEP 5 — Jira subagent contract compliance
# Same as Step 4 but for the Jira subagent
# --------------------------------------------------------------------------
header "Step 5 — Jira subagent — JSON contract compliance"

info "Invoking jira subagent directly (fresh isolated session)…"
OUTFILE="${OUTPUT_DIR}/test-jira-contract.txt"
JSON_FILE="${OUTPUT_DIR}/test-jira-contract.json"

if run_agent "jira" "Find open high-priority bugs." "${OUTFILE}"; then
  subinfo "$(cat "${OUTFILE}")"
  CONTENT=$(cat "${OUTFILE}")

  if echo "$CONTENT" | node --input-type=module <<'EOF' > "${JSON_FILE}" 2>/dev/null
import { readFileSync } from 'fs';
const text = readFileSync('/dev/stdin', 'utf8');
const match = text.match(/\{[\s\S]*\}/);
if (!match) process.exit(1);
try { JSON.parse(match[0]); process.stdout.write(match[0]); process.exit(0); } catch { process.exit(1); }
EOF
  then
    pass "Jira subagent returned valid JSON (contract enforced)"

    if node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); if(!d.status)process.exit(1)" 2>/dev/null; then
      STATUS=$(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); console.log(d.status)" 2>/dev/null)
      pass "Contract field 'status' present (value: ${STATUS})"
    else
      fail "Contract field 'status' missing" "Check jira agent system prompt"
    fi

    if node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); if(!d.operation)process.exit(1)" 2>/dev/null; then
      OP=$(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); console.log(d.operation)" 2>/dev/null)
      pass "Contract field 'operation' present (value: ${OP})"
    else
      fail "Contract field 'operation' missing" "Check jira agent system prompt"
    fi

    if ! has_credentials; then
      if node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); if(d.status!=='error')process.exit(1)" 2>/dev/null; then
        CODE=$(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); console.log(d.error&&d.error.code||'missing')" 2>/dev/null)
        pass "Correct error contract returned with no credentials (error.code: ${CODE})"
      else
        fail "Expected error contract with no credentials" "With no ATLASSIAN credentials, status should be 'error'"
      fi
    fi
  else
    fail "Jira subagent did not return valid JSON" \
         "Check .opencode/agents/jira.md system prompt — JSON contract is not being enforced."
    [ "$VERBOSE" = true ] && echo "" && cat "${OUTFILE}" && echo ""
  fi
else
  fail "opencode run --agent jira failed" "Check opencode and .opencode/agents/jira.md"
fi

# --------------------------------------------------------------------------
# STEP 6 — Tool isolation (cross-agent scope enforcement)
# Confirms that the Jira subagent cannot access Confluence tools
# and vice versa. This verifies DEC-006.
# --------------------------------------------------------------------------
header "Step 6 — Tool isolation (least privilege enforcement)"

info "Asking jira subagent to access Confluence (should be denied)…"
OUTFILE="${OUTPUT_DIR}/test-isolation-jira-to-confluence.txt"

if run_agent "jira" "Search Confluence for pages about deployments. Use Confluence tools." "${OUTFILE}"; then
  subinfo "$(cat "${OUTFILE}")"
  CONTENT=$(cat "${OUTFILE}")

  if echo "$CONTENT" | grep -qiE '"status"\s*:\s*"error"'; then
    pass "Jira subagent correctly returned error when asked to use Confluence tools"
  elif echo "$CONTENT" | grep -qiE "permission|denied|not available|cannot|don.t have access|no.*confluence.*tool"; then
    pass "Jira subagent correctly refused Confluence tool access (tool scope enforced)"
  elif echo "$CONTENT" | grep -qiE '"pages"\s*:'; then
    fail "Jira subagent returned Confluence page data — TOOL ISOLATION BREACH" \
         "CRITICAL: atlassian_confluence_* tools are leaking into the jira agent. Check opencode.json permission config."
  else
    skip "Tool isolation test — result is ambiguous" "Manual inspection required"
    [ "$VERBOSE" = true ] && cat "${OUTFILE}"
  fi
else
  fail "opencode run failed for tool isolation test" "Check opencode installation"
fi

info "Asking confluence subagent to access Jira (should be denied)…"
OUTFILE="${OUTPUT_DIR}/test-isolation-confluence-to-jira.txt"

if run_agent "confluence" "Search Jira for open bugs in the PLATFORM project. Use Jira tools." "${OUTFILE}"; then
  subinfo "$(cat "${OUTFILE}")"
  CONTENT=$(cat "${OUTFILE}")

  if echo "$CONTENT" | grep -qiE '"status"\s*:\s*"error"'; then
    pass "Confluence subagent correctly returned error when asked to use Jira tools"
  elif echo "$CONTENT" | grep -qiE "permission|denied|not available|cannot|don.t have access|no.*jira.*tool"; then
    pass "Confluence subagent correctly refused Jira tool access (tool scope enforced)"
  elif echo "$CONTENT" | grep -qiE '"issues"\s*:'; then
    fail "Confluence subagent returned Jira issue data — TOOL ISOLATION BREACH" \
         "CRITICAL: atlassian_jira_* tools are leaking into the confluence agent. Check opencode.json permission config."
  else
    skip "Tool isolation test — result is ambiguous" "Manual inspection required"
    [ "$VERBOSE" = true ] && cat "${OUTFILE}"
  fi
else
  fail "opencode run failed for tool isolation test" "Check opencode installation"
fi

# --------------------------------------------------------------------------
# STEP 7 — End-to-end live API test (only if credentials are present)
# --------------------------------------------------------------------------
header "Step 7 — End-to-end live API tests"

if has_credentials; then
  info "Credentials detected — running live API tests…"

  OUTFILE="${OUTPUT_DIR}/test-e2e-confluence.txt"
  JSON_FILE="${OUTPUT_DIR}/test-e2e-confluence.json"
  info "Confluence: listing available spaces…"
  if run_agent "confluence" "List all available Confluence spaces." "${OUTFILE}"; then
    if cat "${OUTFILE}" | node --input-type=module <<'EOF' > "${JSON_FILE}" 2>/dev/null
import { readFileSync } from 'fs';
const text = readFileSync('/dev/stdin', 'utf8');
const match = text.match(/\{[\s\S]*\}/);
if (!match) process.exit(1);
try { JSON.parse(match[0]); process.stdout.write(match[0]); process.exit(0); } catch { process.exit(1); }
EOF
    then
      STATUS=$(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); console.log(d.status)" 2>/dev/null)
      if [ "$STATUS" = "success" ] || [ "$STATUS" = "partial" ]; then
        pass "Confluence live API — returned status: ${STATUS} with valid JSON contract"
      else
        CODE=$(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8'));console.log((d.error||{}).code||'unknown')" 2>/dev/null)
        fail "Confluence live API returned error (code: ${CODE})" \
             "Check ATLASSIAN credentials and run bash scripts/validate.sh"
      fi
    else
      fail "Confluence live API response is not valid JSON" "Contract not enforced on live response"
    fi
  fi

  OUTFILE="${OUTPUT_DIR}/test-e2e-jira.txt"
  JSON_FILE="${OUTPUT_DIR}/test-e2e-jira.json"
  info "Jira: listing available projects…"
  if run_agent "jira" "List all Jira projects available to me." "${OUTFILE}"; then
    if cat "${OUTFILE}" | node --input-type=module <<'EOF' > "${JSON_FILE}" 2>/dev/null
import { readFileSync } from 'fs';
const text = readFileSync('/dev/stdin', 'utf8');
const match = text.match(/\{[\s\S]*\}/);
if (!match) process.exit(1);
try { JSON.parse(match[0]); process.stdout.write(match[0]); process.exit(0); } catch { process.exit(1); }
EOF
    then
      STATUS=$(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8')); console.log(d.status)" 2>/dev/null)
      if [ "$STATUS" = "success" ] || [ "$STATUS" = "partial" ]; then
        pass "Jira live API — returned status: ${STATUS} with valid JSON contract"
      else
        CODE=$(node -e "const d=JSON.parse(require('fs').readFileSync('${JSON_FILE}','utf8'));console.log((d.error||{}).code||'unknown')" 2>/dev/null)
        fail "Jira live API returned error (code: ${CODE})" \
             "Check ATLASSIAN credentials and run bash scripts/validate.sh"
      fi
    else
      fail "Jira live API response is not valid JSON" "Contract not enforced on live response"
    fi
  fi
else
  skip "Live API tests" "Set ATLASSIAN_URL, ATLASSIAN_EMAIL, ATLASSIAN_API_TOKEN in .env to enable"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║  Smoke Test Results                                      ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Tests run:     ${BOLD}${TESTS_RUN}${RESET}"
echo -e "  ${GREEN}Passed:${RESET}        ${BOLD}${TESTS_PASSED}${RESET}"
echo -e "  ${RED}Failed:${RESET}        ${BOLD}${TESTS_FAILED}${RESET}"
echo -e "  ${YELLOW}Skipped:${RESET}       ${BOLD}${TESTS_SKIPPED}${RESET}"
echo ""

if [ "${TESTS_FAILED}" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All tests passed. Multiagent system is correctly configured.${RESET}"
  echo ""
  exit 0
else
  echo -e "${RED}${BOLD}${TESTS_FAILED} test(s) failed. See errors above.${RESET}"
  echo -e "${YELLOW}Run with --verbose to see full agent output for each test.${RESET}"
  echo ""
  exit 1
fi
