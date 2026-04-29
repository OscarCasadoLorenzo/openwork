# Test 3.1: Natural Language Workflow - Find Recent Architecture Decisions

**Date**: 2026-04-29  
**Result**: ✅ PASS  
**Execution Time**: ~1.2 seconds

---

## Test Objective

Validate end-to-end natural language workflow where the orchestrator:
1. Understands user intent from natural language
2. Constructs appropriate CQL query
3. Calls Confluence MCP tools directly
4. Presents results in user-friendly format with actionable links

---

## Test Execution

### User Request (Natural Language)
```
Show me recent architecture decisions or technical design documents from Confluence
```

### Orchestrator Workflow

**Step 1: Intent Understanding**
- User wants: Architecture decision records (ADRs) or design documents
- Filter: Recent (implicitly within last few weeks/months)
- Output format: Summary with links

**Step 2: CQL Query Construction**
```cql
type = page 
AND (title ~ "architecture" OR title ~ "design" OR title ~ "ADR") 
ORDER BY lastModified DESC
```

**Reasoning**:
- `type = page` - Exclude blog posts, attachments
- Title matching - Target documents likely to contain architecture/design content
- `ORDER BY lastModified DESC` - Prioritize recently updated documents
- Limit 8 - Reasonable sample size for summary

**Step 3: MCP Tool Invocation**
```bash
confluence_datacenter_search
  cql: "type=page AND (title~\"architecture\" OR title~\"design\" OR title~\"ADR\") ORDER BY lastModified DESC"
  limit: 8
  expand: "version,space,history.lastUpdated"
```

**Step 4: Results Processing**
- Extract key metadata: ID, title, space, version, last modified, author
- Generate clickable URLs for user navigation
- Format as readable summary

---

## Test Results

### Query Performance
- **Response time**: ~500ms
- **Total matches**: 8 documents returned (more available)
- **API status**: 200 OK

### Documents Found

| ID | Title | Space | Version | Last Modified | Author |
|---|---|---|---|---|---|
| 761926618 | ADR: Starter-Based Architecture for Data Products Streaming API | AIHUB | v10 | 2026-04-29 | Juan Antonio Pedraza |
| 285007542 | Architecture Roadmap | SP (Sportsbook) | v325 | 2026-04-28 | Jose Antonio Perez |
| 105525053 | Poker API Architecture Refresh | POK | v12 | 2026-04-27 | Sheila Naujoks |
| 741358889 | HL Deployment Design | AIHUB | v4 | 2026-04-27 | Pedro Martos |
| 741357950 | Architecture Ownership | PDEV | v2 | 2026-04-26 | Samuel Gomez |
| 761927089 | Architecture & HL Design | POK | v1 | 2026-04-24 | Stoyko Nalbantov |
| 250273299 | 1 - Products: High Level Poker Architecture and setup | POK | v78 | 2026-04-24 | Lyubomir Mandzhukov |
| 741358278 | Data as a product - High level architecture [WIP] | POK | v1 | 2026-04-23 | Nikola Petrushevski |

### Key Insights

**Most Recent**: 
- **ADR for Data Products Streaming API** updated TODAY (2026-04-29)
- Active architecture work across multiple teams (AIHUB, Sportsbook, Poker)

**Highly Collaborative Documents**:
- **Architecture Roadmap** (SP space): 325 versions - extremely active document
- **Poker Architecture and setup**: 78 versions - long-running architectural reference

**Active Spaces**:
- **AIHUB** (Artificial Intelligence): 2 recent architecture docs
- **POK** (Poker): 4 architecture documents (most active)
- **SP** (Sportsbook): 1 major roadmap doc
- **PDEV** (Product Development): 1 ownership doc

---

## Natural Language Summary (User-Facing)

I found **8 recent architecture and design documents** across your Confluence instance:

### 🆕 Most Recent (Last 3 Days)
1. **[ADR: Starter-Based Architecture for Data Products Streaming API](https://thewiki.techcorpapps.com/spaces/AIHUB/pages/761926618)** (AIHUB)
   - Updated: TODAY at 3:45 AM
   - Version 10 by Juan Antonio Pedraza
   
2. **[Architecture Roadmap](https://thewiki.techcorpapps.com/spaces/SP/pages/285007542)** (Sportsbook)
   - Updated: Yesterday at 11:57 AM
   - Version 325 (highly collaborative) by Jose Antonio Perez

3. **[Poker API Architecture Refresh](https://thewiki.techcorpapps.com/spaces/POK/pages/105525053)** (Poker)
   - Updated: April 27
   - Version 12 by Sheila Naujoks

### 📋 Other Recent Documents (Last Week)
- [HL Deployment Design](https://thewiki.techcorpapps.com/spaces/AIHUB/pages/741358889) - AIHUB (Apr 27)
- [Architecture Ownership](https://thewiki.techcorpapps.com/spaces/PDEV/pages/741357950) - Product Dev (Apr 26)
- [Architecture & HL Design](https://thewiki.techcorpapps.com/spaces/POK/pages/761927089) - Poker (Apr 24)
- [High Level Poker Architecture and setup](https://thewiki.techcorpapps.com/spaces/POK/pages/250273299) - Poker (Apr 24)
- [Data as a product - High level architecture [WIP]](https://thewiki.techcorpapps.com/spaces/POK/pages/741358278) - Poker (Apr 23)

**Trend**: Poker team has 4 active architecture documents this week, indicating significant architectural work in progress.

---

## Validation Checklist

- ✅ **Natural language understanding** - Correctly interpreted "recent architecture decisions"
- ✅ **CQL construction** - Generated appropriate query with multiple title filters
- ✅ **Sorting logic** - Used `ORDER BY lastModified DESC` for recency
- ✅ **Metadata expansion** - Retrieved version, space, author, timestamps
- ✅ **URL generation** - Created clickable links to actual pages
- ✅ **Data quality** - All 8 results are genuinely architecture/design related
- ✅ **User-friendly output** - Formatted as readable summary with highlights
- ✅ **Actionable results** - User can immediately click through to read full docs
- ✅ **Performance** - Sub-second query execution
- ✅ **Real-time data** - Found document updated TODAY

---

## Technical Details

### API Call
```bash
GET /rest/api/content/search?cql=<query>&limit=8&expand=version,space,history.lastUpdated
Authorization: Bearer <PAT>
```

### Response Structure
```json
{
  "results": [
    {
      "id": "761926618",
      "title": "ADR: Starter-Based Architecture for Data Products Streaming API",
      "space": {"key": "AIHUB", "name": "Artificial Intelligence"},
      "version": {
        "number": 10,
        "when": "2026-04-29T03:45:52.000-04:00",
        "by": {"displayName": "Juan Antonio Pedraza"}
      },
      "_links": {
        "webui": "/spaces/AIHUB/pages/761926618/..."
      }
    }
  ]
}
```

### Field Mapping
| Confluence Field | Extracted As | Purpose |
|---|---|---|
| `id` | Document ID | Unique identifier |
| `title` | Document title | Human-readable name |
| `space.key` | Space abbreviation | Context/team |
| `space.name` | Space full name | Readable context |
| `version.number` | Version count | Collaboration metric |
| `version.when` | Last modified timestamp | Recency |
| `version.by.displayName` | Author name | Attribution |
| `_links.webui` | Page URL | Direct navigation |

---

## Observations

### Strengths
1. **Real-time accuracy** - Found document updated within hours
2. **Relevant results** - All 8 results are genuinely architecture/design docs
3. **Rich metadata** - Version history shows document maturity
4. **Multi-team visibility** - Results span 4 different teams/spaces
5. **Clickable output** - User can immediately access full documents

### Architecture Pattern Validation
- ✅ **DEC-002 compliance**: Orchestrator called `confluence_datacenter_search` directly (no agent delegation)
- ✅ **CQL construction**: Agent successfully mapped natural language → CQL
- ✅ **Read-only**: Only search operation performed (no writes)
- ✅ **Performance**: Single API call, sub-second response

### User Experience
- Natural language input → Structured, actionable output
- No raw JSON exposed to user
- Clear presentation with highlights and links
- Trend analysis provided (Poker team activity)

---

## Potential Improvements

1. **Date filtering**: Could add explicit date range (e.g., `lastModified >= 2026-04-01`)
2. **Space filtering**: Could ask user which team/space to focus on
3. **Label filtering**: Could add `label = "adr"` if ADRs are tagged
4. **Content preview**: Could fetch first paragraph of each document
5. **Change velocity**: Could calculate updates/day for each doc

---

## Conclusion

**Test Status**: ✅ PASS

The natural language workflow successfully:
- Understood user intent without explicit CQL knowledge
- Constructed semantically appropriate query
- Retrieved relevant, recent architecture documents
- Presented results in user-friendly, actionable format
- Demonstrated real-time data access (TODAY's update captured)

This validates that the Confluence integration can handle realistic user queries and provide valuable, immediately usable results.

**Next**: Proceed to Test 3.2 (Multi-step workflow with page detail retrieval)
