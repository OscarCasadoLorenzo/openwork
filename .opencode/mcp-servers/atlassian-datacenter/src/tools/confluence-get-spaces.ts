/**
 * confluence_datacenter_get_spaces
 * List all accessible Confluence spaces
 */

import type { AtlassianClient } from '../client.js';
import { z } from 'zod';

export const confluenceGetSpacesTool = {
  name: 'confluence_datacenter_get_spaces',
  description:
    'List all Confluence spaces accessible to the current user. Useful for discovering available spaces before searching.',
  inputSchema: z.object({
    limit: z
      .number()
      .min(1)
      .max(500)
      .optional()
      .default(50)
      .describe('Maximum number of spaces to return (default: 50)'),
    start: z
      .number()
      .min(0)
      .optional()
      .default(0)
      .describe('Starting index for pagination (default: 0)'),
    type: z
      .enum(['global', 'personal'])
      .optional()
      .describe('Filter by space type: global, personal (default: all)'),
  }),
};

interface ConfluenceSpace {
  key: string;
  name: string;
  type: string;
  status: string;
  _links: {
    webui: string;
  };
}

interface ConfluenceSpacesResult {
  results: ConfluenceSpace[];
  start: number;
  limit: number;
  size: number;
  _links: {
    next?: string;
  };
}

export async function handleConfluenceGetSpaces(
  client: AtlassianClient,
  input: z.infer<typeof confluenceGetSpacesTool.inputSchema>
) {
  const { limit, start, type } = input;

  try {
    const params: Record<string, any> = { limit, start };
    if (type) {
      params.type = type;
    }

    const result = await client.get<ConfluenceSpacesResult>('rest/api/space', params);

    if (!result) {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(
              {
                error: 'NO_SPACES',
                message: 'No spaces found or request failed',
              },
              null,
              2
            ),
          },
        ],
      };
    }

    // Format spaces for the agent
    const formatted = {
      total: result.size,
      returned: result.results.length,
      start: result.start,
      has_more: !!result._links.next,
      spaces: result.results.map((space) => ({
        key: space.key,
        name: space.name,
        type: space.type,
        status: space.status,
        url: space._links.webui,
      })),
    };

    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(formatted, null, 2),
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: JSON.stringify(
            {
              error: 'GET_SPACES_FAILED',
              message: error instanceof Error ? error.message : 'Unknown error',
            },
            null,
            2
          ),
        },
      ],
    };
  }
}
