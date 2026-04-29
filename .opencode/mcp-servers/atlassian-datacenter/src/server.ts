import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { AtlassianClient } from './client.js';
import {
  jiraGetIssueTool,
  handleGetIssue,
  jiraSearchTool,
  handleSearchIssues,
  jiraGetCommentsTool,
  handleGetComments,
} from './tools/index.js';

// Environment validation
const JIRA_URL = process.env.JIRA_URL;
const JIRA_PAT = process.env.JIRA_PAT;

if (!JIRA_URL) {
  console.error('Missing required environment variable: JIRA_URL');
  console.error('  -> Set it in .env: JIRA_URL=https://jira.yourcompany.com');
  process.exit(1);
}

if (!JIRA_PAT) {
  console.error('Missing required environment variable: JIRA_PAT');
  console.error('  -> Set it in .env: JIRA_PAT=your_personal_access_token');
  process.exit(1);
}

// Initialize Jira client
const jiraClient = new AtlassianClient({
  baseUrl: JIRA_URL,
  token: JIRA_PAT,
  name: 'Jira',
  sslVerify: process.env.JIRA_SSL_VERIFY !== 'false',
});

// Create MCP server
const server = new McpServer({
  name: 'atlassian-datacenter',
  version: '0.1.0',
});

// Register Jira tools using the registerTool API
server.registerTool(
  jiraGetIssueTool.name,
  {
    description: jiraGetIssueTool.description,
    inputSchema: jiraGetIssueTool.inputSchema,
  },
  async (input) => handleGetIssue(jiraClient, input)
);

server.registerTool(
  jiraSearchTool.name,
  {
    description: jiraSearchTool.description,
    inputSchema: jiraSearchTool.inputSchema,
  },
  async (input) => handleSearchIssues(jiraClient, input)
);

server.registerTool(
  jiraGetCommentsTool.name,
  {
    description: jiraGetCommentsTool.description,
    inputSchema: jiraGetCommentsTool.inputSchema,
  },
  async (input) => handleGetComments(jiraClient, input)
);

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Atlassian Data Center MCP server running');
  console.error(`  Connected to: ${JIRA_URL}`);
  console.error(
    `  Tools: ${[jiraGetIssueTool.name, jiraSearchTool.name, jiraGetCommentsTool.name].join(', ')}`
  );
}

main().catch((error) => {
  console.error('Server failed to start:', error);
  process.exit(1);
});
