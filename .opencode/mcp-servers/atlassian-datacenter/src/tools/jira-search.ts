import { z } from 'zod';
import type { AtlassianClient } from '../client.js';
import type { JiraSearchResult } from '../types.js';

export const jiraSearchTool = {
  name: 'jira_datacenter_search_issues',
  description:
    'Search Jira issues using JQL (Jira Query Language) with pagination support',
  inputSchema: z.object({
    jql: z
      .string()
      .describe(
        'JQL query string (e.g., "project = PROJ AND status = Open")'
      ),
    maxResults: z
      .number()
      .optional()
      .default(50)
      .describe('Maximum number of results to return (default: 50)'),
    startAt: z
      .number()
      .optional()
      .default(0)
      .describe('Starting index for pagination (default: 0)'),
    fields: z
      .array(z.string())
      .optional()
      .describe('Fields to include in response (default: all)'),
  }),
};

export async function handleSearchIssues(
  client: AtlassianClient,
  input: z.infer<typeof jiraSearchTool.inputSchema>
) {
  const { jql, maxResults, startAt, fields } = input;

  console.error(`[jira] Searching with JQL: ${jql}`);

  const result = await client.get<JiraSearchResult>('rest/api/2/search', {
    jql,
    startAt,
    maxResults,
    fields: fields?.join(',') || '*all',
  });

  if (!result) {
    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify(
            {
              status: 'error',
              operation: 'search_issues',
              error: {
                code: 'SEARCH_FAILED',
                message: `JQL query failed: ${jql}`,
                remediation:
                  'Check JQL syntax and field names. Test query in Jira UI first.',
                jql,
              },
            },
            null,
            2
          ),
        },
      ],
    };
  }

  return {
    content: [
        {
          type: 'text' as const,
          text: JSON.stringify(
            {
              status: 'success',
            operation: 'search_issues',
            summary: `Found ${result.total} issues matching JQL query (returned ${result.issues.length})`,
            data: {
              issues: result.issues.map((issue) => ({
                key: issue.key,
                id: issue.id,
                summary: issue.fields.summary,
                status: issue.fields.status.name,
                assignee: issue.fields.assignee?.displayName || null,
                priority: issue.fields.priority?.name || null,
                created: issue.fields.created,
                updated: issue.fields.updated,
              })),
            },
            pagination: {
              startAt: result.startAt,
              maxResults: result.maxResults,
              total: result.total,
              hasMore:
                result.startAt + result.maxResults < result.total,
            },
            jql,
          },
          null,
          2
        ),
      },
    ],
  };
}
