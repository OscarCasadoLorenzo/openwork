import { z } from 'zod';
import type { AtlassianClient } from '../client.js';
import type { JiraCommentsResponse } from '../types.js';

export const jiraGetCommentsTool = {
  name: 'jira_datacenter_get_comments',
  description:
    'Fetch all comments from a Jira issue, sorted by created date',
  inputSchema: z.object({
    issueKey: z.string().regex(/^[A-Z]+-\d+$/),
    maxResults: z
      .number()
      .optional()
      .default(50)
      .describe('Maximum number of comments to return'),
    orderBy: z
      .enum(['created', '-created'])
      .optional()
      .default('-created')
      .describe(
        'Sort order: created (oldest first) or -created (newest first)'
      ),
  }),
};

export async function handleGetComments(
  client: AtlassianClient,
  input: z.infer<typeof jiraGetCommentsTool.inputSchema>
) {
  const { issueKey, maxResults, orderBy } = input;

  console.error(`[jira] Fetching comments from ${issueKey}...`);

  const data = await client.get<JiraCommentsResponse>(
    `rest/api/2/issue/${issueKey}/comment`,
    { maxResults, orderBy }
  );

  if (!data) {
    return {
      content: [
        {
          type: 'text' as const,
          text: JSON.stringify(
            {
              status: 'error',
              operation: 'get_comments',
              error: {
                code: 'COMMENTS_FETCH_FAILED',
                message: `Failed to fetch comments for ${issueKey}`,
                remediation:
                  'Check issue exists and you have read permissions',
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
            operation: 'get_comments',
            summary: `Retrieved ${data.comments.length} comments from ${issueKey}`,
            data: {
              comments: data.comments.map((comment) => ({
                id: comment.id,
                author: comment.author.displayName,
                body: comment.body.substring(0, 1000), // Truncate long comments
                created: comment.created,
                updated: comment.updated,
                isInternal: comment.visibility ? true : false,
              })),
            },
            pagination: {
              startAt: data.startAt,
              maxResults: data.maxResults,
              total: data.total,
            },
          },
          null,
          2
        ),
      },
    ],
  };
}
