import { z } from 'zod';
import type { AtlassianClient } from '../client.js';
import type { JiraIssue } from '../types.js';

export const jiraGetIssueTool = {
  name: 'jira_datacenter_get_issue',
  description:
    'Fetch a single Jira issue by key (e.g., PROJ-123) with all fields and metadata',
  inputSchema: z.object({
    issueKey: z
      .string()
      .regex(
        /^[A-Z]+-\d+$/,
        'Must be format PROJECT-NUMBER (e.g., PROJ-123)'
      ),
    expand: z
      .array(z.string())
      .optional()
      .describe(
        'Fields to expand: renderedFields, changelog, transitions, etc.'
      ),
  }),
};

export async function handleGetIssue(
  client: AtlassianClient,
  input: z.infer<typeof jiraGetIssueTool.inputSchema>
) {
  const { issueKey, expand } = input;

  console.error(`[jira] Fetching issue ${issueKey}...`);

  const issue = await client.get<JiraIssue>(`rest/api/2/issue/${issueKey}`, {
    expand: expand?.join(',') || 'renderedFields',
    fields: '*all',
  });

  if (!issue) {
    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify(
            {
              status: 'error',
              operation: 'get_issue',
              error: {
                code: 'ISSUE_NOT_FOUND',
                message: `Issue ${issueKey} not found`,
                remediation:
                  'Check the issue key exists and you have read permissions',
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
            operation: 'get_issue',
            summary: `Retrieved issue ${issue.key}: ${issue.fields.summary}`,
            data: {
              key: issue.key,
              id: issue.id,
              summary: issue.fields.summary,
              description: issue.fields.description || null,
              status: {
                name: issue.fields.status.name,
                category: issue.fields.status.statusCategory.name,
              },
              assignee: issue.fields.assignee?.displayName || null,
              reporter: issue.fields.reporter?.displayName || null,
              priority: issue.fields.priority?.name || null,
              created: issue.fields.created,
              updated: issue.fields.updated,
              labels: issue.fields.labels || [],
              components:
                issue.fields.components?.map((c: { name: string }) => c.name) || [],
              // Include all fields for custom field access
              allFields: issue.fields,
            },
          },
          null,
          2
        ),
      },
    ],
  };
}
