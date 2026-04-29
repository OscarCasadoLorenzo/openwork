#!/usr/bin/env bash
# =============================================================================
# scripts/validate.sh
# Pre-flight validation for the multiagent-work template.
#
# Checks:
#   1. Required environment variables are set and non-empty
#   2. Confluence Cloud API is reachable with the given credentials
#   3. Jira Cloud API is reachable with the given credentials
#   4. Required .opencode/ directory structure is present
#   5. Node.js is available (needed to run mcp-atlassian via npx)
#
# Usage:
#   bash scripts/validate.sh
#
# Exit codes:
#   0  All checks passed
#   1  One or more checks failed
# =============================================================================

set -euo pipefail

# --------------------------------------------------------------------------
# Colour helpers (degrade gracefully if terminal has no colour support)
# --------------------------------------------------------------------------
if [ -t 1 ] && command -v tput &>/dev/null && tput colors &>/dev/null; then
  GREEN=$(tput setaf 2)
  RED=$(tput setaf 1)
  YELLOW=$(tput setaf 3)
  BOLD=$(tput bold)
  RESET=$(tput sgr0)
else
  GREEN="" RED="" YELLOW="" BOLD="" RESET=""
fi

PASS="${GREEN}[✓]${RESET}"
FAIL="${RED}[✗]${RESET}"
INFO="${YELLOW}[!]${RESET}"

ERRORS=0

pass() { echo -e "${PASS} $1"; }
fail() {
  echo -e "${FAIL} $1"
  echo -e "    ${YELLOW}→ $2${RESET}"
  ERRORS=$((ERRORS + 1))
}
info() { echo -e "${INFO} $1"; }
header() { echo -e "\n${BOLD}$1${RESET}"; }

# --------------------------------------------------------------------------
# Load .env if it exists (does not override already-set shell variables)
# --------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${REPO_ROOT}/.env"

if [ -f "${ENV_FILE}" ]; then
  # shellcheck disable=SC1090
  set -a
  source "${ENV_FILE}"
  set +a
  info "Loaded environment from .env"
else
  info ".env file not found — using shell environment variables only"
fi

# --------------------------------------------------------------------------
# 1. Environment variables
# --------------------------------------------------------------------------
header "1. Environment variables"

check_env_var() {
  local var_name="$1"
  local hint="$2"
  local value="${!var_name:-}"
  if [ -z "${value}" ]; then
    fail "${var_name} is not set" "${hint}"
  else
    pass "${var_name} is set"
  fi
}

check_env_var "ATLASSIAN_URL" \
  "Add it to your .env file. Format: https://your-jira-domain or https://your-org.atlassian.net"

check_env_var "ATLASSIAN_EMAIL" \
  "Add it to your .env file. Use the email linked to your Atlassian account."

# Check for either PAT (self-hosted) or API token (Cloud)
if [ -z "${ATLASSIAN_PAT:-}" ] && [ -z "${ATLASSIAN_API_TOKEN:-}" ]; then
  fail "Neither ATLASSIAN_PAT nor ATLASSIAN_API_TOKEN is set" \
    "For self-hosted Jira: Add ATLASSIAN_PAT to .env. For Cloud: Add ATLASSIAN_API_TOKEN"
else
  if [ -n "${ATLASSIAN_PAT:-}" ]; then
    pass "ATLASSIAN_PAT is set (self-hosted Jira Data Center)"
  else
    pass "ATLASSIAN_API_TOKEN is set (Atlassian Cloud)"
  fi
fi

# --------------------------------------------------------------------------
# 2. Confluence API reachability
# --------------------------------------------------------------------------
header "2. Confluence API"

if [ -n "${ATLASSIAN_URL:-}" ]; then
  # Detect if this is Cloud or self-hosted based on URL pattern
  if [[ "${ATLASSIAN_URL}" =~ \.atlassian\.net ]]; then
    IS_CLOUD=true
    CONFLUENCE_ENDPOINT="${ATLASSIAN_URL}/wiki/rest/api/content?limit=1"
    if [ -n "${ATLASSIAN_EMAIL:-}" ] && { [ -n "${ATLASSIAN_API_TOKEN:-}" ] || [ -n "${ATLASSIAN_PAT:-}" ]; }; then
      HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        --max-time 10 \
        --user "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
        "${CONFLUENCE_ENDPOINT}" 2>/dev/null || echo "000")
    fi
  else
    IS_CLOUD=false
    CONFLUENCE_ENDPOINT="${ATLASSIAN_URL}/wiki/rest/api/content?limit=1"
    if [ -n "${ATLASSIAN_PAT:-}" ]; then
      HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        --max-time 10 \
        -H "Authorization: Bearer ${ATLASSIAN_PAT}" \
        "${CONFLUENCE_ENDPOINT}" 2>/dev/null || echo "000")
    elif [ -n "${ATLASSIAN_API_TOKEN:-}" ]; then
      HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        --max-time 10 \
        --user "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
        "${CONFLUENCE_ENDPOINT}" 2>/dev/null || echo "000")
    fi
  fi

  if [ -n "${HTTP_STATUS:-}" ]; then
    case "${HTTP_STATUS}" in
      200)
        pass "Confluence API reachable (HTTP ${HTTP_STATUS})"
        ;;
      302)
        info "Confluence returned HTTP 302 (redirect) — Confluence may not be installed. This is common for Jira-only instances."
        ;;
      401)
        fail "Confluence API returned HTTP 401 (Unauthorized)" \
          "Check your credentials. For self-hosted: verify ATLASSIAN_PAT. For Cloud: verify ATLASSIAN_API_TOKEN."
        ;;
      403)
        fail "Confluence API returned HTTP 403 (Forbidden)" \
          "Your account may not have Confluence access. Contact your admin."
        ;;
      404)
        info "Confluence returned HTTP 404 — Confluence may not be installed or uses a different path. This is common for Jira-only instances."
        ;;
      000)
        fail "Confluence API is unreachable (connection failed)" \
          "Check ATLASSIAN_URL and your network connection."
        ;;
      *)
        fail "Confluence API returned unexpected HTTP ${HTTP_STATUS}" \
          "Investigate manually with appropriate curl command for your instance type."
        ;;
    esac
  else
    info "Skipping Confluence API check — required env vars missing"
  fi
else
  info "Skipping Confluence API check — ATLASSIAN_URL not set"
fi

# --------------------------------------------------------------------------
# 3. Jira API reachability
# --------------------------------------------------------------------------
header "3. Jira API"

if [ -n "${ATLASSIAN_URL:-}" ]; then
  JIRA_ENDPOINT="${ATLASSIAN_URL}/rest/api/2/myself"
  
  # Detect if this is Cloud or self-hosted based on URL pattern
  if [[ "${ATLASSIAN_URL}" =~ \.atlassian\.net ]]; then
    if [ -n "${ATLASSIAN_EMAIL:-}" ] && [ -n "${ATLASSIAN_API_TOKEN:-}" ]; then
      HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        --max-time 10 \
        --user "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
        "${JIRA_ENDPOINT}" 2>/dev/null || echo "000")
    fi
  else
    if [ -n "${ATLASSIAN_PAT:-}" ]; then
      HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        --max-time 10 \
        -H "Authorization: Bearer ${ATLASSIAN_PAT}" \
        "${JIRA_ENDPOINT}" 2>/dev/null || echo "000")
    elif [ -n "${ATLASSIAN_EMAIL:-}" ] && [ -n "${ATLASSIAN_API_TOKEN:-}" ]; then
      HTTP_STATUS=$(curl --silent --output /dev/null --write-out "%{http_code}" \
        --max-time 10 \
        --user "${ATLASSIAN_EMAIL}:${ATLASSIAN_API_TOKEN}" \
        "${JIRA_ENDPOINT}" 2>/dev/null || echo "000")
    fi
  fi

  if [ -n "${HTTP_STATUS:-}" ]; then
    case "${HTTP_STATUS}" in
      200)
        pass "Jira API reachable (HTTP ${HTTP_STATUS})"
        ;;
      401)
        fail "Jira API returned HTTP 401 (Unauthorized)" \
          "Check your credentials. For self-hosted: verify ATLASSIAN_PAT. For Cloud: verify ATLASSIAN_API_TOKEN."
        ;;
      403)
        fail "Jira API returned HTTP 403 (Forbidden)" \
          "Your account may not have Jira access. Contact your admin."
        ;;
      404)
        fail "Jira API returned HTTP 404 (Not Found)" \
          "Check ATLASSIAN_URL is correct."
        ;;
      000)
        fail "Jira API is unreachable (connection failed)" \
          "Check ATLASSIAN_URL and your network connection."
        ;;
      *)
        fail "Jira API returned unexpected HTTP ${HTTP_STATUS}" \
          "Investigate manually with appropriate curl command for your instance type."
        ;;
    esac
  else
    info "Skipping Jira API check — required env vars missing"
  fi
else
  info "Skipping Jira API check — ATLASSIAN_URL not set"
fi

# --------------------------------------------------------------------------
# 4. Repository structure
# --------------------------------------------------------------------------
header "4. Repository structure"

check_dir() {
  local dir="$1"
  local description="$2"
  if [ -d "${REPO_ROOT}/${dir}" ]; then
    pass "${dir}/ exists (${description})"
  else
    fail "${dir}/ is missing" \
      "Run: mkdir -p ${REPO_ROOT}/${dir}"
  fi
}

check_file() {
  local file="$1"
  local description="$2"
  if [ -f "${REPO_ROOT}/${file}" ]; then
    pass "${file} exists (${description})"
  else
    fail "${file} is missing" \
      "This file is required. See README.md for setup instructions."
  fi
}

check_dir ".opencode/agents"      "subagent definitions"
check_dir ".opencode/skills"      "skill definitions"
check_dir ".opencode/docs"        "structured knowledge store"
check_dir ".opencode/docs/agents"     "per-agent knowledge docs"
check_dir ".opencode/docs/contracts"  "JSON output contracts"
check_dir ".opencode/docs/decisions"  "architecture decision records"
check_dir "scripts"               "utility scripts"

check_file ".env.example"         "credential contract template"
check_file ".opencode/opencode.json" "central OpenCode config"
check_file "AGENTS.md"            "orchestrator rules"

# --------------------------------------------------------------------------
# 5. Node.js availability
# --------------------------------------------------------------------------
header "5. Runtime dependencies"

if command -v node &>/dev/null; then
  NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
  NODE_MAJOR=$(echo "${NODE_VERSION}" | sed 's/v\([0-9]*\).*/\1/')
  if [ "${NODE_MAJOR}" -ge 18 ] 2>/dev/null; then
    pass "Node.js available (${NODE_VERSION}) — required for mcp-atlassian"
  else
    fail "Node.js ${NODE_VERSION} is too old (need ≥ 18)" \
      "Install Node.js 18 or later: https://nodejs.org"
  fi
else
  fail "Node.js is not installed" \
    "Install Node.js 18 or later: https://nodejs.org — required to run mcp-atlassian via npx."
fi

if command -v curl &>/dev/null; then
  pass "curl available — required for API checks"
else
  fail "curl is not installed" \
    "Install curl: brew install curl (macOS) or apt install curl (Linux)"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "─────────────────────────────────────────────────"

if [ "${ERRORS}" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}All checks passed. Ready to run OpenCode.${RESET}"
  echo ""
  echo "  Start a session with:  opencode"
  echo ""
  exit 0
else
  echo -e "${RED}${BOLD}Validation failed — ${ERRORS} error(s) found.${RESET}"
  echo -e "${YELLOW}Fix the errors above before running OpenCode.${RESET}"
  echo ""
  exit 1
fi
