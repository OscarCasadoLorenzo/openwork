#!/usr/bin/env bash
# =============================================================================
# scripts/validate.sh
# Pre-flight validation for the multiagent-work template.
#
# Checks:
#   1. Required environment variables are set and non-empty
#   2. Confluence API is reachable (if configured)
#   3. Jira API is reachable (Cloud or Data Center)
#   4. Required .opencode/ directory structure is present
#   5. Node.js is available (needed to run MCP servers)
#   6. Custom MCP server dependencies (if using Data Center)
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

# Determine deployment type(s) based on environment variables
JIRA_DEPLOYMENT=""
CONFLUENCE_DEPLOYMENT=""

# Check Jira deployment
if [ -n "${JIRA_DC_URL:-}" ] && [ -n "${JIRA_DC_PAT:-}" ]; then
  JIRA_DEPLOYMENT="datacenter"
  info "Detected Jira Data Center deployment (self-hosted)"
elif [ -n "${ATLASSIAN_URL:-}" ] && [ -n "${ATLASSIAN_PAT:-}" ]; then
  JIRA_DEPLOYMENT="datacenter-legacy"
  info "Detected Jira Data Center deployment (legacy variable naming)"
fi

# Check Confluence deployment
if [ -n "${CONFLUENCE_URL:-}" ] && [ -n "${CONFLUENCE_PAT:-}" ]; then
  CONFLUENCE_DEPLOYMENT="datacenter"
  info "Detected Confluence Data Center deployment (self-hosted)"
fi

# Validate we have at least one configured
if [ -z "${JIRA_DEPLOYMENT}" ] && [ -z "${CONFLUENCE_DEPLOYMENT}" ]; then
  fail "No Atlassian services configured" \
    "For Jira Data Center: Set JIRA_DC_URL and JIRA_DC_PAT. For Confluence Data Center: Set CONFLUENCE_URL and CONFLUENCE_PAT"
fi

# Validate Jira environment variables
case "${JIRA_DEPLOYMENT}" in
  datacenter)
    check_env_var "JIRA_DC_URL" \
      "Add it to your .env file. Format: https://your-jira-domain (no trailing slash)"
    check_env_var "JIRA_DC_PAT" \
      "Generate a Personal Access Token in Jira: Profile > Personal Access Tokens"
    
    # SSL verification is optional, default to true
    if [ -z "${JIRA_DC_SSL_VERIFY:-}" ]; then
      info "JIRA_DC_SSL_VERIFY not set, defaulting to 'true'"
    else
      pass "JIRA_DC_SSL_VERIFY is set to '${JIRA_DC_SSL_VERIFY}'"
    fi
    ;;
    
  datacenter-legacy)
    check_env_var "ATLASSIAN_URL" \
      "Add it to your .env file. Format: https://your-jira-domain (no trailing slash)"
    check_env_var "ATLASSIAN_PAT" \
      "Generate a Personal Access Token in Jira: Profile > Personal Access Tokens"
    
    info "Consider migrating to JIRA_DC_* variable naming for clarity"
    ;;
esac

# Validate Confluence environment variables
if [ "${CONFLUENCE_DEPLOYMENT}" = "datacenter" ]; then
  check_env_var "CONFLUENCE_URL" \
    "Add it to your .env file. Format: https://your-confluence-domain (no trailing slash)"
  check_env_var "CONFLUENCE_PAT" \
    "Generate a Personal Access Token in Confluence: /plugins/personalaccesstokens/usertokens.action"
  
  # SSL verification is optional, default to true
  if [ -z "${CONFLUENCE_SSL_VERIFY:-}" ]; then
    info "CONFLUENCE_SSL_VERIFY not set, defaulting to 'true'"
  else
    pass "CONFLUENCE_SSL_VERIFY is set to '${CONFLUENCE_SSL_VERIFY}'"
  fi
fi

# --------------------------------------------------------------------------
# 2. Confluence API reachability
# --------------------------------------------------------------------------
header "2. Confluence API"

if [ "${CONFLUENCE_DEPLOYMENT}" = "datacenter" ]; then
  if [ -n "${CONFLUENCE_URL:-}" ] && [ -n "${CONFLUENCE_PAT:-}" ]; then
    CONFLUENCE_ENDPOINT="${CONFLUENCE_URL}/rest/api/content?limit=1"
    
    CURL_OPTS="--silent --output /dev/null --write-out %{http_code} --max-time 10"
    
    # Handle SSL verification
    if [ "${CONFLUENCE_SSL_VERIFY:-true}" = "false" ]; then
      CURL_OPTS="${CURL_OPTS} --insecure"
      info "SSL verification disabled (CONFLUENCE_SSL_VERIFY=false)"
    fi
    
    HTTP_STATUS=$(curl ${CURL_OPTS} \
      -H "Authorization: Bearer ${CONFLUENCE_PAT}" \
      "${CONFLUENCE_ENDPOINT}" 2>/dev/null || echo "000")

    case "${HTTP_STATUS}" in
      200)
        pass "Confluence API reachable (HTTP ${HTTP_STATUS})"
        ;;
      302)
        info "Confluence returned HTTP 302 (redirect) — this may indicate SSO is required"
        info "The Personal Access Token might not work with this Confluence instance"
        info "Check with your Confluence admin if PAT authentication is supported"
        ;;
      401)
        fail "Confluence API returned HTTP 401 (Unauthorized)" \
          "Check CONFLUENCE_PAT in .env. Ensure your PAT is valid and not expired."
        ;;
      403)
        fail "Confluence API returned HTTP 403 (Forbidden)" \
          "Your account may not have Confluence access. Contact your Confluence admin."
        ;;
      404)
        info "Confluence returned HTTP 404 — verify the Confluence URL is correct"
        ;;
      000)
        fail "Confluence API is unreachable (connection failed)" \
          "Check CONFLUENCE_URL and your network connection."
        ;;
      *)
        fail "Confluence API returned unexpected HTTP ${HTTP_STATUS}" \
          "Investigate manually: curl -H \"Authorization: Bearer \${CONFLUENCE_PAT}\" \"${CONFLUENCE_ENDPOINT}\""
        ;;
    esac
  else
    info "Skipping Confluence API check — required env vars missing"
  fi
else
  info "Skipping Confluence API check — no Confluence deployment configured"
fi

# --------------------------------------------------------------------------
# 3. Jira API reachability
# --------------------------------------------------------------------------
header "3. Jira API"

JIRA_URL=""
CURL_OPTS="--silent --output /dev/null --write-out %{http_code} --max-time 10"

case "${JIRA_DEPLOYMENT}" in
  datacenter)
    JIRA_URL="${JIRA_DC_URL}"
    JIRA_ENDPOINT="${JIRA_URL}/rest/api/2/myself"
    
    # Handle SSL verification
    if [ "${JIRA_DC_SSL_VERIFY:-true}" = "false" ]; then
      CURL_OPTS="${CURL_OPTS} --insecure"
      info "SSL verification disabled (JIRA_DC_SSL_VERIFY=false)"
    fi
    
    if [ -n "${JIRA_DC_PAT:-}" ]; then
      HTTP_STATUS=$(curl ${CURL_OPTS} \
        -H "Authorization: Bearer ${JIRA_DC_PAT}" \
        "${JIRA_ENDPOINT}" 2>/dev/null || echo "000")
    else
      info "Skipping Jira API check — JIRA_DC_PAT not set"
    fi
    ;;
    
  datacenter-legacy)
    JIRA_URL="${ATLASSIAN_URL}"
    JIRA_ENDPOINT="${JIRA_URL}/rest/api/2/myself"
    
    if [ -n "${ATLASSIAN_PAT:-}" ]; then
      HTTP_STATUS=$(curl ${CURL_OPTS} \
        -H "Authorization: Bearer ${ATLASSIAN_PAT}" \
        "${JIRA_ENDPOINT}" 2>/dev/null || echo "000")
    else
      info "Skipping Jira API check — ATLASSIAN_PAT not set"
    fi
    ;;
    
  *)
    info "Skipping Jira API check — no Jira deployment configured"
    ;;
esac

if [ -n "${HTTP_STATUS:-}" ]; then
  case "${HTTP_STATUS}" in
    200)
      pass "Jira API reachable (HTTP ${HTTP_STATUS})"
      ;;
    401)
      if [ "${JIRA_DEPLOYMENT}" = "datacenter" ]; then
        fail "Jira API returned HTTP 401 (Unauthorized)" \
          "Check JIRA_DC_PAT in .env. Ensure your PAT is valid and not expired."
      else
        fail "Jira API returned HTTP 401 (Unauthorized)" \
          "Check ATLASSIAN_PAT in .env. Ensure your PAT is valid and not expired."
      fi
      ;;
    403)
      fail "Jira API returned HTTP 403 (Forbidden)" \
        "Your account may not have Jira access. Contact your Jira admin."
      ;;
    404)
      fail "Jira API returned HTTP 404 (Not Found)" \
        "Check Jira URL is correct: ${JIRA_URL}"
      ;;
    000)
      fail "Jira API is unreachable (connection failed)" \
        "Check Jira URL and your network connection: ${JIRA_URL}"
      ;;
    *)
      fail "Jira API returned unexpected HTTP ${HTTP_STATUS}" \
        "Investigate manually: curl -H \"Authorization: Bearer \${JIRA_DC_PAT}\" \"${JIRA_ENDPOINT}\""
      ;;
  esac
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

# Check for custom MCP server if Data Center deployment
if [ "${JIRA_DEPLOYMENT}" = "datacenter" ]; then
  check_dir ".opencode/mcp-servers" "custom MCP servers"
  check_dir ".opencode/mcp-servers/atlassian-datacenter" "Jira Data Center MCP server"
fi

check_file ".env.example"         "credential contract template"
check_file ".opencode/opencode.json" "central OpenCode config"
check_file "AGENTS.md"            "orchestrator rules"

# --------------------------------------------------------------------------
# 5. Runtime dependencies
# --------------------------------------------------------------------------
header "5. Runtime dependencies"

if command -v node &>/dev/null; then
  NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
  NODE_MAJOR=$(echo "${NODE_VERSION}" | sed 's/v\([0-9]*\).*/\1/')
  if [ "${NODE_MAJOR}" -ge 18 ] 2>/dev/null; then
    pass "Node.js available (${NODE_VERSION}) — required for MCP servers"
  else
    fail "Node.js ${NODE_VERSION} is too old (need ≥ 18)" \
      "Install Node.js 18 or later: https://nodejs.org"
  fi
else
  fail "Node.js is not installed" \
    "Install Node.js 18 or later: https://nodejs.org — required to run MCP servers"
fi

if command -v curl &>/dev/null; then
  pass "curl available — required for API checks"
else
  fail "curl is not installed" \
    "Install curl: brew install curl (macOS) or apt install curl (Linux)"
fi

# Additional checks for Data Center deployment
if [ "${JIRA_DEPLOYMENT}" = "datacenter" ]; then
  if command -v pnpm &>/dev/null; then
    PNPM_VERSION=$(pnpm --version 2>/dev/null || echo "unknown")
    pass "pnpm available (${PNPM_VERSION}) — required for custom MCP server"
  else
    fail "pnpm is not installed" \
      "Install pnpm: npm install -g pnpm — required to run custom Jira Data Center MCP server"
  fi
  
  # Check if custom MCP server has dependencies installed
  if [ -f ".opencode/mcp-servers/atlassian-datacenter/package.json" ]; then
    if [ -d ".opencode/mcp-servers/atlassian-datacenter/node_modules" ]; then
      pass "Jira Data Center MCP server dependencies installed"
    else
      fail "Jira Data Center MCP server dependencies not installed" \
        "Run: cd .opencode/mcp-servers/atlassian-datacenter && pnpm install"
    fi
  fi
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
