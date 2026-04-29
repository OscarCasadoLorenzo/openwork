---
name: confluence-ops
description: Workflow recipes for Confluence Cloud operations — space traversal, CQL query construction, content extraction, and pagination handling. Load this skill when working with Confluence hierarchies, building search queries, or processing large result sets.
license: MIT
compatibility: opencode
metadata:
  domain: atlassian-confluence
  version: "1.0"
---

# Confluence Operations — Workflow Recipes

## 1. Space Traversal

### Traverse a space hierarchy recursively

To build a full tree of pages in a space:

1. Call `atlassian_confluence_get_pages` with the `space_key` to get top-level pages.
2. For each page, call `atlassian_confluence_get_child_pages` with the `page_id`.
3. Repeat step 2 for each child page until no more children are returned.
4. Accumulate results into the `pages` array of your response.

**Pagination guard**: Each call may return a maximum of 25 pages by default. Always check `has_more` in the result and increment `start` by the page size until `has_more` is `false`.

```
Depth-first pseudocode:
  function traverse(page_id):
    children = get_child_pages(page_id, start=0)
    while children.has_more:
      children += get_child_pages(page_id, start=next_start)
    for each child:
      traverse(child.id)
```

**Stop condition**: Limit recursion to 3 levels deep by default unless the user explicitly requests a full deep scan. Deep scans on large spaces can generate hundreds of API calls.

---

## 2. CQL Query Construction

Confluence Query Language (CQL) is the structured search syntax for Confluence Cloud.

### Common CQL patterns

| Goal | CQL query |
|---|---|
| Search by keyword in a space | `text ~ "keyword" AND space = "ENG"` |
| Pages updated in last 7 days | `lastModified >= now("-7d") AND type = page` |
| Pages with a specific label | `label = "runbook" AND space = "OPS"` |
| Pages by a specific author | `creator = "user@company.com"` |
| Pages containing a title keyword | `title ~ "architecture" AND type = page` |
| Recently created pages | `created >= now("-30d") AND type = page ORDER BY created DESC` |
| Pages in a specific parent | `ancestor = 123456 AND type = page` |

### CQL operators reference

| Operator | Meaning | Example |
|---|---|---|
| `=` | Exact match | `space = "ENG"` |
| `~` | Contains (full-text) | `text ~ "deployment"` |
| `!=` | Not equal | `type != blogpost` |
| `IN` | Match any in list | `space IN ("ENG", "OPS")` |
| `AND` | Both conditions true | `space = "ENG" AND label = "runbook"` |
| `OR` | Either condition true | `label = "runbook" OR label = "playbook"` |
| `ORDER BY` | Sort results | `ORDER BY lastModified DESC` |

### Translating natural language to CQL

| User says | CQL to use |
|---|---|
| "Find pages about deployments" | `text ~ "deployment" AND type = page` |
| "Show me runbooks in the OPS space" | `label = "runbook" AND space = "OPS"` |
| "What pages were updated this week?" | `lastModified >= now("-7d") AND type = page ORDER BY lastModified DESC` |
| "Find the onboarding guide" | `title ~ "onboarding" AND type = page` |
| "Pages under the Platform architecture section" | `ancestor = <parent_page_id> AND type = page` |

---

## 3. Content Extraction

### Stripping Confluence storage format

The Confluence REST API returns page content in Confluence Storage Format (XHTML-based). When populating `pages[].content` or `pages[].excerpt`:

1. Remove all XML/HTML tags: strip anything between `<` and `>`
2. Decode HTML entities: `&amp;` → `&`, `&lt;` → `<`, `&gt;` → `>`, `&nbsp;` → space
3. Collapse consecutive whitespace to single spaces
4. Truncate `excerpt` to 500 characters at a word boundary

Do not include raw markup in the `excerpt` or `content` fields.

### Extracting tables

If a page contains a structured table (common in runbooks and status pages):
1. Identify `<table>` tags in the storage format
2. Extract header row (`<th>` cells) as column names
3. Extract data rows (`<td>` cells) as values
4. Represent as a plain-text summary in the `excerpt` field

---

## 4. Pagination Handling

### Standard pagination loop

All Confluence list endpoints use `start` + `limit` pagination. Default `limit` is 25.

```
results = []
start = 0
limit = 25

loop:
  response = api_call(start=start, limit=limit)
  results += response.results
  if response.size < limit or not response._links.next:
    break
  start += limit
```

Always populate the response contract's `pagination` object:
```json
{
  "pagination": {
    "total": <response._total or results.length>,
    "returned": <results.length>,
    "has_more": <true if _links.next exists>,
    "next_start": <start + limit if has_more>
  }
}
```

### Capping results

Unless the user asks for all results, cap at 50 items per response to avoid context overflow. Set `has_more: true` and document `next_start` so the orchestrator can request additional pages if needed.

---

## 5. Common Error Patterns

| HTTP status | `error.code` | Likely cause |
|---|---|---|
| 401 | `AUTH_FAILED` | Invalid or expired API token |
| 403 | `PERMISSION_DENIED` | Account lacks access to the space/page |
| 404 | `NOT_FOUND` | Page ID or space key does not exist |
| 429 | `RATE_LIMITED` | Too many requests — add a short delay and retry |
| 500/503 | `NETWORK_ERROR` | Atlassian service issue — retry once |

For `RATE_LIMITED`: mention in `remediation` that the user should wait 30 seconds before retrying.
