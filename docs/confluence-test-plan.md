# Confluence Agent & MCP Server Test Plan

**Status**: ✅ READY TO EXECUTE - Authentication verified working  
**Created**: 2026-04-29  
**Last Updated**: 2026-04-29

---

## Executive Summary

This test plan validates the Confluence Data Center integration across three layers:
1. **MCP Server Layer** - Direct tool functionality with Bearer token auth
2. **Confluence Agent Layer** - JSON contract compliance and behavior rules
3. **Integration Layer** - Orchestrator delegation and end-to-end workflows

### Authentication Status

**✅ RESOLVED**: Confluence instance at `https://thewiki.techcorpapps.com` supports PAT authentication successfully.

**Initial Blocker (RESOLVED)**: The original Confluence instance at `https://confluence.constellation.soprasteria.com` was behind Azure AD Application Proxy and did not support PAT authentication. Switched to working instance at `https://thewiki.techcorpapps.com`.

**Test 0.1 Result**: ✅ PASS - HTTP 200 response from API

---

## Overview

This test plan validates the Confluence Data Center integration across three layers:
1. **MCP Server Layer** - Direct tool functionality with Bearer token auth
2. **Confluence Agent Layer** - JSON contract compliance and behavior rules
3. **Integration Layer** - Orchestrator delegation and end-to-end workflows

---

## Test Environment

### Confluence Instance (Working)
- **URL**: https://thewiki.techcorpapps.com
- **Authentication**: Personal Access Token (PAT) - Bearer token
- **Status**: ✅ HTTP 200 - API accessible

### Confluence Spaces Available for Testing
- **PDEV**: Product Development  
  Test Page: https://thewiki.techcorpapps.com/spaces/PDEV/pages/709552315/TSI+-+03+-+March+2026
  Page ID: `709552315`
  
- **Additional spaces**: To be discovered via `get_spaces` tool

### Prerequisites

- [x] `.env` file configured with valid `CONFLUENCE_URL`, `CONFLUENCE_PAT`, `CONFLUENCE_SSL_VERIFY`
- [x] Validation script passes: `bash scripts/validate.sh` ✅ ALL CHECKS PASSED
- [x] MCP server dependencies installed: `cd .opencode/mcp-servers/atlassian-datacenter && pnpm install`
- [x] Authentication verified working (Test 0.1 passed)

### Known Constraints
- **Working Instance**: `https://thewiki.techcorpapps.com` supports PAT authentication
- **Non-working Instance**: `https://confluence.constellation.soprasteria.com` uses Azure App Proxy and blocks API access
- **Test Data**: Use existing pages in PDEV space and other discovered spaces

---

## Layer 0: Critical Authentication Test

**This test MUST pass before proceeding to other layers**

### Test 0.1: Direct API Authentication

**Purpose**: Verify that authentication works and API calls are not redirected to SSO

**Execute via command line**:
```bash
curl -s -w "\nHTTP_CODE: %{http_code}\n" \
  -H "Authorization: Bearer ${CONFLUENCE_PAT}" \
  "${CONFLUENCE_URL}/rest/api/space?limit=1"
```

**Expected Behavior**:
- ✅ **HTTP 200** - Authentication works, proceed to Layer 1
- ❌ **HTTP 302** - SSO redirect, authentication blocked - STOP HERE
- ❌ **HTTP 401** - Invalid credentials - Check PAT and regenerate

**Test Execution Log**:
```
Date: 2026-04-29
Result: ✅ PASS
HTTP Status: 200 OK
Response: Valid JSON with space data returned
Instance: https://thewiki.techcorpapps.com
Notes: Switched from confluence.constellation.soprasteria.com to thewiki.techcorpapps.com
       New instance supports PAT authentication successfully
Action Required: None - proceed to Layer 1 tests
```

---

## Layer 1: MCP Server Tools (Direct Testing)

**PREREQUISITE**: Test 0.1 must return HTTP 200

**Goal**: Verify each MCP tool works independently with the Confluence API.

### Test 1.1: `confluence_datacenter_get_spaces` - List Spaces

**Execute via OpenCode**:
```
Use the confluence_datacenter_get_spaces tool to list all spaces with limit=10
```

**Expected Behavior**:
- ✅ Returns JSON with `total`, `returned`, `start`, `has_more`, `spaces[]`
- ✅ Each space has: `key`, `name`, `type`, `status`, `url`
- ✅ Should include space: `PDEV` (Product Development)
- ✅ URLs are valid Confluence webui links
- ❌ Error → Returns error `NO_SPACES` or `GET_SPACES_FAILED`

**Validation Points**:
- Does the tool return data or an error?
- If error: what's the error code and message?
- If success: is PDEV listed?
- What other spaces are visible?

**Test Execution Log**:
```
Date: 
Result: ✅ READY (Test 0.1 passed - authentication working)
Output:

Notes:

Action Items:
```

---

### Test 1.2: `confluence_datacenter_search` - CQL Search

**Test Case A**: Simple CQL query
```
Use confluence_datacenter_search with CQL: "type = page" and limit=5
```

**Expected Behavior**:
- ✅ Returns JSON with `total`, `returned`, `start`, `has_more`, `pages[]`
- ✅ Each page has: `id`, `title`, `type`, `space_key`, `space_name`, `url`, `version`, `last_updated`, `author`, `excerpt`
- ✅ `excerpt` is text-only (HTML stripped), max 500 chars
- ❌ Error → Returns error `NO_RESULTS` or `SEARCH_FAILED`

**Test Execution Log**:
```
Date:
Result: ✅ READY (Test 0.1 passed - authentication working)
Output:

Notes:

Action Items:
```

---

**Test Case B**: Space-filtered search (ENGHUB)
```
Use confluence_datacenter_search with CQL: "space = ENGHUB AND type = page" and limit=5
```

**Expected Behavior**:
- ✅ Returns only pages from ENGHUB space
- ✅ All `space_key` values equal "ENGHUB"
- ✅ All URLs contain `/spaces/ENGHUB/`

**Test Execution Log**:
```
Date:
Result: ✅ READY (Test 0.1 passed - authentication working)
Output:

Notes:

Action Items:
```

---

**Test Case C**: Space-filtered search (THEWORKSHOP)
```
Use confluence_datacenter_search with CQL: "space = THEWORKSHOP AND type = page" and limit=5
```

**Expected Behavior**:
- ✅ Returns only pages from THEWORKSHOP space
- ✅ All `space_key` values equal "THEWORKSHOP"
- ✅ All URLs contain `/spaces/THEWORKSHOP/`

**Test Execution Log**:
```
Date:
Result: ✅ READY (Test 0.1 passed - authentication working)
Output:

Notes:

Action Items:
```

---

**Test Case D**: Pagination
```
Step 1: Use confluence_datacenter_search with CQL: "type = page", limit=2, start=0

Step 2: Use confluence_datacenter_search with CQL: "type = page", limit=2, start=2
```

**Expected Behavior**:
- ✅ First call: `has_more: true`, returns 2 pages
- ✅ Second call: Different pages returned (IDs don't overlap with first call)
- ✅ Pagination offsets work correctly

**Test Execution Log**:
```
Date:
Result: ✅ READY (Test 0.1 passed - authentication working)
Output (Call 1):

Output (Call 2):

Notes:

Action Items:
```

---

### Test 1.3: `confluence_datacenter_get_page` - Get Page by ID

**Prerequisite**: Note a page ID from Test 1.2 results

**Known Page IDs for Testing**:
- ENGHUB: `888832841` (Engineering Hub home page)
- THEWORKSHOP: `160531281` (THE WORKSHOP Home page)

**Test Case A**: Get ENGHUB home page
```
Use confluence_datacenter_get_page with page_id: "888832841"
```

**Expected Behavior**:
- ✅ Returns JSON with `id`, `title`, `type`, `status`, `space_key`, `space_name`, `url`, `version`, `last_updated`, `author`, `labels[]`, `ancestors[]`, `content`
- ✅ `title` = "Engineering Hub" (or similar)
- ✅ `space_key` = "ENGHUB"
- ✅ `content` field is populated with full page content
- ✅ `labels` is an array (may be empty)
- ✅ `ancestors` shows parent pages (may be empty for top-level pages)

**Test Execution Log**:
```
Date:
Result: ✅ READY (Test 0.1 passed - authentication working)
Output:

Notes:

Action Items:
```

---

**Test Case B**: Get THEWORKSHOP home page
```
Use confluence_datacenter_get_page with page_id: "160531281"
```

**Expected Behavior**:
- ✅ Returns JSON with full page data
- ✅ `title` = "THE WORKSHOP Home" (or similar)
- ✅ `space_key` = "THEWORKSHOP"
- ✅ `content` field is populated

**Test Execution Log**:
```
Date:
Result: ✅ READY (Test 0.1 passed - authentication working)
Output:

Notes:

Action Items:
```

---

**Test Case C**: Non-existent page ID
```
Use confluence_datacenter_get_page with page_id: "999999999"
```

**Expected Behavior**:
- ✅ Returns error `PAGE_NOT_FOUND`
- ✅ Error message explains the page doesn't exist or access denied

**Test Execution Log**:
```
Date:
Result: ✅ READY (Test 0.1 passed - authentication working)
Output:

Notes:

Action Items:
```

---

### Test 1.4: Error Handling - Invalid CQL

**Test**:
```
Use confluence_datacenter_search with CQL: "invalid query syntax ~~~"
```

**Expected Behavior**:
- ✅ Returns error `SEARCH_FAILED` or `NO_RESULTS`
- ✅ Error message contains useful information about what failed
- ✅ Does not crash or hang

**Test Execution Log**:
```
Date:
Result: ✅ READY (Test 0.1 passed - authentication working)
Output:

Notes:

Action Items:
```

---

## Layer 2: Confluence Agent (Contract Compliance)

**PREREQUISITE**: Layer 1 tests must pass

**Goal**: Verify the Confluence subagent produces valid JSON responses matching the schema.

### Test 2.1: Agent Response Schema - Success Case

**Test via Orchestrator**:
```
@confluence list all spaces
```

**Expected Behavior**:
- ✅ Agent returns a **single JSON object only** (no prose, no markdown)
- ✅ JSON validates against `.opencode/docs/contracts/confluence-response.schema.json`
- ✅ Required fields present: `status`, `operation`
- ✅ `status` = `"success"`
- ✅ `operation` = `"list_space"`
- ✅ `summary` field is present and ≤ 3 sentences
- ✅ `spaces[]` array is present with at least one entry
- ✅ `pagination` object is present

**Validation**:
- Copy the agent's JSON output
- Verify all required fields are present
- Check that no extra prose/markdown exists outside the JSON

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 1 ready to execute)
Output:

Notes:

Action Items:
```

---

### Test 2.2: Agent Response Schema - Search Success

**Test**:
```
@confluence search for pages in ENGHUB space
```

**Expected Behavior**:
- ✅ Agent returns single JSON object only
- ✅ `status` = `"success"`
- ✅ `operation` = `"search"`
- ✅ `summary` describes what was found
- ✅ `pages[]` array contains results
- ✅ `pagination` object is present

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 1 ready to execute)
Output:

Notes:

Action Items:
```

---

### Test 2.3: Agent Response Schema - Error Case

**Test via Orchestrator** (trigger intentional error):
```
@confluence get page with ID: "invalid_page_id_12345"
```

**Expected Behavior**:
- ✅ Agent returns a **single JSON object only**
- ✅ `status` = `"error"`
- ✅ `operation` = `"get_page"`
- ✅ `error` object is present with `code`, `message`, and `remediation`
- ✅ `code` is one of: `AUTH_FAILED`, `NOT_FOUND`, `PERMISSION_DENIED`, `RATE_LIMITED`, `NETWORK_ERROR`, `INVALID_QUERY`, `UNKNOWN`
- ✅ `summary` is NOT present (only required on success/partial)

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 1 ready to execute)
Output:

Notes:

Action Items:
```

---

### Test 2.4: Agent Behavior - Natural Language CQL Construction

**Test**:
```
@confluence find pages about "engineering" in the ENGHUB space
```

**Expected Behavior**:
- ✅ Agent constructs a valid CQL query (e.g., `text ~ "engineering" AND space = ENGHUB`)
- ✅ Agent may load `confluence-ops` skill for CQL construction (optional)
- ✅ Returns `operation: "search"`
- ✅ `summary` describes what was found in natural language
- ✅ Results are from ENGHUB space only

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 1 ready to execute)
Output:

Notes:
- Record the CQL query the agent constructed
- Did it load the confluence-ops skill?

Action Items:
```

---

### Test 2.5: Agent Behavior - Read-Only Enforcement

**Test**:
```
@confluence create a new page titled "Test Page" in ENGHUB space
```

**Expected Behavior**:
- ✅ Agent refuses with `status: "error"`
- ✅ `error.code` = `"PERMISSION_DENIED"`
- ✅ `error.remediation` explains write operations are not supported

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 1 ready to execute)
Output:

Notes:

Action Items:
```

---

### Test 2.6: Agent Behavior - Page Content Retrieval

**Test**:
```
@confluence get the full content of the Engineering Hub page (ID: 888832841)
```

**Expected Behavior**:
- ✅ Returns `operation: "get_page"`
- ✅ `status: "success"`
- ✅ Response includes full page `content` field
- ✅ `summary` mentions the page title and space

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 1 ready to execute)
Output:

Notes:

Action Items:
```

---

### Test 2.7: Agent Behavior - Pagination Handling

**Test**:
```
@confluence search for all pages in THEWORKSHOP space, showing the first 3 results
```

Then:
```
@confluence continue showing the next 3 results from the previous search
```

**Expected Behavior**:
- ✅ Agent uses pagination correctly (start=0, then start=3)
- ✅ Returns different pages in each response
- ✅ May load `confluence-ops` skill for pagination recipe
- ✅ `pagination.has_more` indicates if more results exist
- ✅ Agent remembers the context from first query

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 1 ready to execute)
Output (First Request):

Output (Second Request):

Notes:
- Did agent remember the CQL query from first request?
- Were pagination offsets calculated correctly?

Action Items:
```

---

## Layer 3: Integration (Orchestrator → Agent → MCP)

**PREREQUISITE**: Layer 2 tests must pass

**Goal**: Verify end-to-end workflows through the orchestrator.

### Test 3.1: Orchestrator Delegation

**Test**:
```
Show me the spaces available in Confluence
```

**Expected Behavior**:
- ✅ Orchestrator delegates to `@confluence` agent (not handled directly)
- ✅ User sees a natural-language summary (from the agent's `summary` field)
- ✅ User does NOT see raw JSON (orchestrator parses it)
- ✅ Spaces are listed in readable format

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 2 ready to execute)
Output:

Notes:
- Did orchestrator correctly identify this as a Confluence task?
- Was the delegation automatic or did user need to use @confluence?

Action Items:
```

---

### Test 3.2: Orchestrator Error Handling

**Test**:
```
Get the Confluence page with ID 999999999
```

**Expected Behavior**:
- ✅ Orchestrator delegates to `@confluence`
- ✅ Agent returns error JSON
- ✅ Orchestrator surfaces the error to the user with remediation guidance
- ✅ User sees: "Page not found" message (not raw JSON)

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 2 ready to execute)
Output:

Notes:

Action Items:
```

---

### Test 3.3: Cross-Agent Workflow - Search and Retrieve

**Scenario**: Find a Confluence page, then retrieve its full content

**Test**:
```
Find the Confluence page about "Engineering Hub" in the ENGHUB space and show me its full content
```

**Expected Behavior**:
- ✅ Orchestrator delegates search to `@confluence`
- ✅ Agent returns page ID and excerpt from search
- ✅ Orchestrator (or agent) fetches full page content via second `get_page` call
- ✅ User sees the page content in readable format

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 2 ready to execute)
Output:

Notes:
- How many MCP tool calls were made? (1 for search + 1 for get_page = 2 expected)
- Did orchestrator compose a nice summary?

Action Items:
```

---

### Test 3.4: Permission Boundary Enforcement

**Test via OpenCode (as orchestrator)**:
```
Call the confluence_datacenter_search tool directly with CQL "type = page"
```

**Expected Behavior**:
- ❌ Orchestrator is **denied** access to `confluence_datacenter_*` tools
- ✅ Error message indicates the orchestrator must delegate to `@confluence` agent
- ✅ Tool permissions are correctly enforced

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 2 ready to execute)
Output:

Notes:

Action Items:
```

---

### Test 3.5: Natural Language Multi-Step Workflow

**Test**:
```
Find all documentation in the ENGHUB space related to "testing" and summarize the key topics covered
```

**Expected Behavior**:
- ✅ Orchestrator delegates search to `@confluence`
- ✅ Agent constructs CQL query with "testing" keyword and ENGHUB space filter
- ✅ Agent returns multiple pages
- ✅ Orchestrator (or user) can optionally fetch full content of interesting pages
- ✅ User gets a composed summary of topics

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 2 ready to execute)
Output:

Notes:

Action Items:
```

---

## Layer 4: Edge Cases & Error Scenarios

**PREREQUISITE**: Layer 3 tests must pass

**Goal**: Validate error handling and edge cases

### Test 4.1: Large Result Set Handling

**Test**:
```
@confluence search for all pages with CQL: "type = page"
```

**Expected Behavior**:
- ✅ Agent handles large result sets (may be 100+ pages)
- ✅ Returns paginated results with `has_more: true`
- ✅ Provides clear summary of total results found
- ✅ Does not timeout or crash

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 3 ready to execute)
Output:

Notes:
- Total pages found:
- Pages returned in first response:
- Was pagination metadata accurate?

Action Items:
```

---

### Test 4.2: Special Characters in Search

**Test**:
```
@confluence search for pages with text containing "C++ & API's"
```

**Expected Behavior**:
- ✅ Agent properly escapes special characters in CQL
- ✅ Search completes without syntax errors
- ✅ Returns relevant results (if any exist)

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 3 ready to execute)
Output:

Notes:

Action Items:
```

---

### Test 4.3: Empty Search Results

**Test**:
```
@confluence search for pages with text "xyzabc123nonexistentterm999"
```

**Expected Behavior**:
- ✅ Returns `status: "success"` (empty result is still success)
- ✅ `pages[]` is empty array
- ✅ `summary` indicates no results found
- ✅ `pagination.total` = 0

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 3 ready to execute)
Output:

Notes:

Action Items:
```

---

### Test 4.4: Invalid Credentials (Intentional Failure)

**Setup**: Temporarily modify `.env` to use invalid PAT
```bash
# In .env, change CONFLUENCE_PAT to an invalid value
CONFLUENCE_PAT=invalid_token_12345
```

**Test**:
```
bash scripts/validate.sh
```

**Expected Behavior**:
- ❌ Validation fails with HTTP 401 error
- ✅ Clear remediation message to regenerate PAT

**Then test via agent**:
```
@confluence list all spaces
```

**Expected Behavior**:
- ✅ Agent returns `error.code: "AUTH_FAILED"`
- ✅ `error.remediation` suggests checking credentials
- ✅ Error is surfaced clearly to user

**Cleanup**: Restore correct `CONFLUENCE_PAT` value

**Test Execution Log**:
```
Date:
Result: ✅ READY (Layer 3 ready to execute)
Output (validation):

Output (agent):

Notes:

Action Items:
- [ ] Restore correct CONFLUENCE_PAT after test
```

---

## Test Execution Summary

### Test Statistics

| Layer | Total Tests | Passed | Failed | Ready | Blocked |
|-------|-------------|--------|--------|-------|---------|
| Layer 0 (Auth) | 1 | 1 | 0 | 0 | 0 |
| Layer 1 (MCP) | 9 | 0 | 0 | 9 | 0 |
| Layer 2 (Agent) | 7 | 0 | 0 | 7 | 0 |
| Layer 3 (Integration) | 5 | 0 | 0 | 5 | 0 |
| Layer 4 (Edge Cases) | 4 | 0 | 0 | 4 | 0 |
| **TOTAL** | **26** | **1** | **0** | **25** | **0** |

### Status Summary

✅ **READY TO EXECUTE**: Test 0.1 (Authentication) passed with HTTP 200

**Impact**: All tests are now unblocked and ready to execute

**Next Steps**:
1. Execute Layer 1 tests (MCP Server Tools)
2. Execute Layer 2 tests (Confluence Agent)
3. Execute Layer 3 tests (Integration)
4. Execute Layer 4 tests (Edge Cases)

---

## Success Criteria

### Minimum Viable (MVP)
- [x] Test 0.1 returns HTTP 200 (authentication works)
- [ ] Test 1.1 returns at least 1 space (PDEV)
- [ ] Test 1.2B returns pages from PDEV space
- [ ] Test 1.3A retrieves page content for known page ID (709552315)
- [ ] Test 1.2B/C return pages from respective spaces
- [ ] Test 1.3A/B retrieve page content for known page IDs
- [ ] Test 2.1 returns valid JSON matching schema
- [ ] Test 3.1 orchestrator delegates correctly

### Full Success
- [ ] All Layer 0 tests pass (authentication)
- [ ] All Layer 1 tests pass (MCP tools)
- [ ] All Layer 2 tests pass (agent contract)
- [ ] All Layer 3 tests pass (integration)
- [ ] All Layer 4 tests pass (edge cases)

---

## Administrator Communication Template

**Subject**: Request for Confluence REST API Access - OAuth 2.0 or Service Principal Setup

**Body**:
```
Hi [Admin Name],

We're implementing AI-powered automation to search and retrieve Confluence documentation
(read-only access). We're experiencing an authentication issue where Personal Access Tokens
are not working due to Azure Application Proxy redirecting all API requests to Microsoft SSO.

Current Situation:
- All REST API calls to https://confluence.constellation.soprasteria.com/rest/api/*
  return HTTP 302 redirect to login.microsoftonline.com
- Personal Access Token authentication is not bypassing the Azure App Proxy layer
- Required spaces: ENGHUB, THEWORKSHOP (read-only)

Request:
Can you help enable API access using one of the following methods:

Option 1 (PREFERRED): Service Principal / App Registration
- Create an Azure AD App Registration for our automation
- Grant read-only permissions to Confluence
- Provide: Client ID, Client Secret, Token Endpoint URL

Option 2: Internal Confluence URL
- Provide an internal/direct Confluence URL that bypasses Azure App Proxy
- This would allow Personal Access Token authentication to work directly

Option 3: App Proxy Configuration
- Configure Azure App Proxy to allow PAT authentication on /rest/api/* endpoints
- Bypass SSO requirement for API automation scenarios

Use Case:
- AI agent automation for documentation search and retrieval
- Read-only operations: search pages, get page content, list spaces
- No create/update/delete operations required

Please let me know which option is feasible and what additional information you need from us.

Thank you!
```

---

## Next Steps

**Once authentication is resolved:**

1. Update this document:
   - [ ] Document the authentication method that worked
   - [ ] Update `.env.example` with new auth variables (if OAuth)
   - [ ] Update validation script if needed

2. Execute test plan:
   - [ ] Run all Layer 0 tests (authentication)
   - [ ] Run all Layer 1 tests (MCP tools)
   - [ ] Run all Layer 2 tests (agent)
   - [ ] Run all Layer 3 tests (integration)
   - [ ] Run all Layer 4 tests (edge cases)

3. Document findings:
   - [ ] Record any issues discovered
   - [ ] Update MCP tools if API response format differs
   - [ ] Refine agent prompts if needed

---

## Appendix: Authentication Details

### Current Configuration (PAT - Not Working)

```bash
CONFLUENCE_URL=https://confluence.constellation.soprasteria.com
CONFLUENCE_PAT=<personal_access_token>
CONFLUENCE_SSL_VERIFY=true
```

**Authentication Method**: Bearer Token  
**Header**: `Authorization: Bearer ${CONFLUENCE_PAT}`  
**Status**: ❌ Blocked by Azure App Proxy (HTTP 302)

### Future Configuration (OAuth 2.0 - To Be Implemented)

**If administrators provide Service Principal access:**

```bash
CONFLUENCE_URL=https://confluence.constellation.soprasteria.com
CONFLUENCE_CLIENT_ID=<azure_ad_client_id>
CONFLUENCE_CLIENT_SECRET=<azure_ad_client_secret>
CONFLUENCE_TENANT_ID=<azure_ad_tenant_id>
CONFLUENCE_TOKEN_ENDPOINT=https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token
```

**Authentication Flow**:
1. Request OAuth token from Azure AD token endpoint
2. Use token with Bearer authentication for Confluence API calls
3. Implement token refresh logic (tokens typically expire after 1 hour)

**MCP Server Changes Required**:
- [ ] Add OAuth 2.0 token acquisition logic
- [ ] Implement token caching and refresh
- [ ] Update client to use OAuth tokens instead of PAT

---

**End of Test Plan**
