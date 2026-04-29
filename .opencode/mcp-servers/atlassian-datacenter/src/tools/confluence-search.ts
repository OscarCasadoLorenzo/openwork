/**
 * confluence_datacenter_search
 * Search for Confluence pages using CQL (Confluence Query Language)
 */

import type { AtlassianClient } from '../client.js';
import { z } from 'zod';

export const confluenceSearchTool = {
  name: 'confluence_datacenter_search',
  description:
    'Search Confluence pages using CQL (Confluence Query Language). Supports full-text search, space filtering, and metadata queries.',
  inputSchema: z.object({
    cql: z
      .string()
      .describe(
        'CQL query string. Examples: "text ~ \\"architecture\\"", "space = ENG AND type = page", "label = onboarding"'
      ),
    limit: z
      .number()
      .min(1)
      .max(100)
      .optional()
      .default(25)
      .describe('Maximum number of results to return (default: 25, max: 100)'),
    start: z
      .number()
      .min(0)
      .optional()
      .default(0)
      .describe('Starting index for pagination (default: 0)'),
    expand: z
      .string()
      .optional()
      .default('space,version,body.view')
      .describe(
        'Comma-separated list of properties to expand: body.view,version,space,metadata.labels,container'
      ),
  }),
};

interface ConfluenceSearchResult {
  results: Array<{
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
    };
    _links: {
      webui: string;
      self: string;
    };
  }>;
  start: number;
  limit: number;
  size: number;
  totalSize: number;
}

export async function handleConfluenceSearch(
  client: AtlassianClient,
  input: z.infer<typeof confluenceSearchTool.inputSchema>
) {
  const { cql, limit, start, expand } = input;

  try {
    const result = await client.get<ConfluenceSearchResult>(
      'rest/api/content/search',
      {
        cql,
        limit,
        start,
        expand,
      }
    );

    if (!result) {
      return {
        content: [
          {
            type: 'text',
            text: JSON.stringify(
              {
                error: 'NO_RESULTS',
                message: 'Search returned no results or failed',
                cql,
              },
              null,
              2
            ),
          },
        ],
      };
    }

    // Format results for the agent
    const formatted = {
      total: result.totalSize,
      returned: result.size,
      start: result.start,
      has_more: result.start + result.size < result.totalSize,
      pages: result.results.map((page) => ({
        id: page.id,
        title: page.title,
        type: page.type,
        space_key: page.space?.key,
        space_name: page.space?.name,
        url: page._links.webui,
        version: page.version?.number,
        last_updated: page.version?.when,
        author: page.version?.by?.displayName,
        excerpt: page.body?.view?.value
          ? stripHtml(page.body.view.value).substring(0, 500)
          : '',
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
              error: 'SEARCH_FAILED',
              message: error instanceof Error ? error.message : 'Unknown error',
              cql,
            },
            null,
            2
          ),
        },
      ],
    };
  }
}

/**
 * Strip HTML tags from content (simple implementation)
 */
function stripHtml(html: string): string {
  return html
    .replace(/<[^>]*>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
