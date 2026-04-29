import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { AtlassianClient } from './client.js';
import {
  // Jira tools
  jiraGetIssueTool,
  handleGetIssue,
  jiraSearchTool,
  handleSearchIssues,
  jiraGetCommentsTool,
  handleGetComments,
  // Confluence tools
  confluenceSearchTool,
  handleConfluenceSearch,
  confluenceGetPageTool,
  handleConfluenceGetPage,
  confluenceGetSpacesTool,
  handleConfluenceGetSpaces,
} from './tools/index.js';

// ============================================================================
// Environment Validation
// ============================================================================

// Jira Data Center
const JIRA_URL = process.env.JIRA_URL;
const JIRA_PAT = process.env.JIRA_PAT;

// Confluence Data Center
const CONFLUENCE_URL = process.env.CONFLUENCE_URL;
const CONFLUENCE_PAT = process.env.CONFLUENCE_PAT;

// Validate at least one service is configured
const hasJira = !!(JIRA_URL && JIRA_PAT);
const hasConfluence = !!(CONFLUENCE_URL && CONFLUENCE_PAT);

if (!hasJira && !hasConfluence) {
  console.error('No Atlassian services configured!');
  console.error('');
  console.error('For Jira Data Center:');
  console.error('  -> Set JIRA_URL=https://jira.yourcompany.com');
  console.error('  -> Set JIRA_PAT=your_jira_personal_access_token');
  console.error('');
  console.error('For Confluence Data Center:');
  console.error('  -> Set CONFLUENCE_URL=https://confluence.yourcompany.com');
  console.error('  -> Set CONFLUENCE_PAT=your_confluence_personal_access_token');
  console.error('');
  process.exit(1);
}

// ============================================================================
// Initialize Clients
// ============================================================================

let jiraClient: AtlassianClient | null = null;
let confluenceClient: AtlassianClient | null = null;

if (hasJira) {
  jiraClient = new AtlassianClient({
    baseUrl: JIRA_URL!,
    token: JIRA_PAT!,
    name: 'Jira',
    sslVerify: process.env.JIRA_SSL_VERIFY !== 'false',
  });
}

if (hasConfluence) {
  confluenceClient = new AtlassianClient({
    baseUrl: CONFLUENCE_URL!,
    token: CONFLUENCE_PAT!,
    name: 'Confluence',
    sslVerify: process.env.CONFLUENCE_SSL_VERIFY !== 'false',
  });
}

// ============================================================================
// Create MCP Server
// ============================================================================

const server = new McpServer({
  name: 'atlassian-datacenter',
  version: '0.2.0',
});

// ============================================================================
// Register Jira Tools
// ============================================================================

if (jiraClient) {
  server.registerTool(
    jiraGetIssueTool.name,
    {
      description: jiraGetIssueTool.description,
      inputSchema: jiraGetIssueTool.inputSchema,
    },
    async (input) => handleGetIssue(jiraClient!, input)
  );

  server.registerTool(
    jiraSearchTool.name,
    {
      description: jiraSearchTool.description,
      inputSchema: jiraSearchTool.inputSchema,
    },
    async (input) => handleSearchIssues(jiraClient!, input)
  );

  server.registerTool(
    jiraGetCommentsTool.name,
    {
      description: jiraGetCommentsTool.description,
      inputSchema: jiraGetCommentsTool.inputSchema,
    },
    async (input) => handleGetComments(jiraClient!, input)
  );
}

// ============================================================================
// Register Confluence Tools
// ============================================================================

if (confluenceClient) {
  server.registerTool(
    confluenceSearchTool.name,
    {
      description: confluenceSearchTool.description,
      inputSchema: confluenceSearchTool.inputSchema,
    },
    async (input) => handleConfluenceSearch(confluenceClient!, input)
  );

  server.registerTool(
    confluenceGetPageTool.name,
    {
      description: confluenceGetPageTool.description,
      inputSchema: confluenceGetPageTool.inputSchema,
    },
    async (input) => handleConfluenceGetPage(confluenceClient!, input)
  );

  server.registerTool(
    confluenceGetSpacesTool.name,
    {
      description: confluenceGetSpacesTool.description,
      inputSchema: confluenceGetSpacesTool.inputSchema,
    },
    async (input) => handleConfluenceGetSpaces(confluenceClient!, input)
  );
}

// ============================================================================
// Start Server
// ============================================================================

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  
  const enabledTools: string[] = [];
  
  if (jiraClient) {
    enabledTools.push(
      jiraGetIssueTool.name,
      jiraSearchTool.name,
      jiraGetCommentsTool.name
    );
  }
  
  if (confluenceClient) {
    enabledTools.push(
      confluenceSearchTool.name,
      confluenceGetPageTool.name,
      confluenceGetSpacesTool.name
    );
  }
  
  console.error('Atlassian Data Center MCP server running');
  if (jiraClient) {
    console.error(`  Jira: ${JIRA_URL}`);
  }
  if (confluenceClient) {
    console.error(`  Confluence: ${CONFLUENCE_URL}`);
  }
  console.error(`  Tools: ${enabledTools.join(', ')}`);
}

main().catch((error) => {
  console.error('Server failed to start:', error);
  process.exit(1);
});
