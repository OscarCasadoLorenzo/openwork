/**
 * confluence_datacenter_get_page
 * Get a specific Confluence page by ID with full content
 */

import type { AtlassianClient } from '../client.js';
import { z } from 'zod';

export const confluenceGetPageTool = {
  name: 'confluence_datacenter_get_page',
  description:
    'Retrieve a specific Confluence page by ID. Returns full page content, metadata, version history, and space information.',
  inputSchema: z.object({
    page_id: z.string().describe('The ID of the Confluence page to retrieve'),
    expand: z
      .string()
      .optional()
      .default('space,version,body.view,metadata.labels,ancestors')
      .describe(
        'Comma-separated list of properties to expand: body.storage,body.view,version,space,metadata.labels,container,ancestors'
      ),
  }),
};

interface ConfluencePage {
  id: string;
  type: string;
  status: string;
  title: string;
  space?: {
    key: string;
    name: string;
  };
  version?: {
    number: number;
    when: string;
    by: {
      displayName: string;
      email?: string;
    };
  };
  body?: {
    view?: {
      value: string;
    };
    storage?: {
      value: string;
    };
  };
  metadata?: {
    labels?: {
      results: Array<{
        name: string;
      }>;
    };
  };
  ancestors?: Array<{
    id: string;
    title: string;
  }>;
  _links: {
    webui: string;
    self: string;
  };
}

export async function handleConfluenceGetPage(
  client: AtlassianClient,
  input: z.infer<typeof confluenceGetPageTool.inputSchema>
) {
  const { page_id, expand } = input;

  try {
    const result = await client.get<ConfluencePage>(
      `rest/api/content/${page_id}`,
      { expand }
    );

    if (!result) {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(
              {
                error: 'PAGE_NOT_FOUND',
                message: `Page with ID ${page_id} not found or access denied`,
                page_id,
              },
              null,
              2
            ),
          },
        ],
      };
    }

    // Format page for the agent
    const formatted = {
      id: result.id,
      title: result.title,
      type: result.type,
      status: result.status,
      space_key: result.space?.key,
      space_name: result.space?.name,
      url: result._links.webui,
      version: result.version?.number,
      last_updated: result.version?.when,
      author: result.version?.by?.displayName,
      labels: result.metadata?.labels?.results.map((l) => l.name) || [],
      ancestors:
        result.ancestors?.map((a) => ({
          id: a.id,
          title: a.title,
        })) || [],
      content: result.body?.view?.value || result.body?.storage?.value || '',
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
              error: 'GET_PAGE_FAILED',
              message: error instanceof Error ? error.message : 'Unknown error',
              page_id,
            },
            null,
            2
          ),
        },
      ],
    };
  }
}
