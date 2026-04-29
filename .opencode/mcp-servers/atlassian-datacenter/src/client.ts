/**
 * HTTP client for Atlassian APIs with Bearer token authentication
 * Ported from em-playbook's _api.py with TypeScript async/await patterns
 */

import type { JiraErrorResponse } from './types.js';
import { jiraConfig } from './config.js';

export interface ClientOptions {
  baseUrl: string;
  token: string;
  name: string;
  sslVerify?: boolean;
}

export class AtlassianClient {
  private baseUrl: string;
  private token: string;
  private name: string;
  private sslVerify: boolean;
  public ok: boolean = true;

  constructor(options: ClientOptions) {
    this.baseUrl = options.baseUrl.replace(/\/$/, ''); // Remove trailing slash
    this.token = options.token;
    this.name = options.name;
    this.sslVerify = options.sslVerify ?? true;
  }

  /**
   * Execute a GET request with Bearer token authentication
   */
  async get<T>(
    path: string,
    params?: Record<string, any>
  ): Promise<T | null> {
    const url = new URL(`${this.baseUrl}/${path.replace(/^\//, '')}`);

    // Add query parameters
    if (params) {
      Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null) {
          url.searchParams.append(key, String(value));
        }
      });
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(
      () => controller.abort(),
      jiraConfig.defaults.timeout
    );

    try {
      const response = await fetch(url.toString(), {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${this.token}`,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (response.status === 200) {
        return (await response.json()) as T;
      }

      // Handle errors (matches em-playbook behavior)
      await this.handleError(response, url.toString());
      return null;
    } catch (error) {
      clearTimeout(timeoutId);

      if (error instanceof Error) {
        if (error.name === 'AbortError') {
          console.error(
            `[${this.name}] Timeout after ${jiraConfig.defaults.timeout}ms on ${url}`
          );
        } else if (error.message.includes('fetch failed')) {
          console.error(`[${this.name}] Connection failed to ${this.baseUrl}`);
          console.error(`  -> Check VPN connection or firewall settings`);
          this.ok = false;
        } else {
          console.error(`[${this.name}] Unexpected error:`, error.message);
        }
      }

      return null;
    }
  }

  /**
   * Handle HTTP error responses with actionable remediation messages
   * Matches em-playbook's error handling pattern
   */
  private async handleError(response: Response, url: string): Promise<void> {
    const status = response.status;

    // Try to parse error details from response body
    let errorDetails: JiraErrorResponse | null = null;
    try {
      errorDetails = await response.json();
    } catch {
      // Ignore JSON parse errors
    }

    switch (status) {
      case 400:
        console.error(`[${this.name}] Bad Request (400) on ${url}`);
        if (errorDetails?.errorMessages) {
          console.error(`  -> ${errorDetails.errorMessages.join(', ')}`);
        }
        break;

      case 401:
        console.error(`[${this.name}] Invalid or expired token (401)`);
        console.error(
          `  -> Regenerate PAT at: ${this.baseUrl}/secure/ViewProfile.jspa`
        );
        console.error(
          `  -> Verify JIRA_PAT environment variable is set correctly`
        );
        this.ok = false;
        break;

      case 403:
        console.error(
          `[${this.name}] No read permissions (403) on ${url}`
        );
        console.error(`  -> Contact your Jira admin to grant read access`);
        this.ok = false;
        break;

      case 404:
        // Silent for 404 (resource not found is sometimes expected)
        // Calling code can check for null response
        break;

      case 503:
        console.error(`[${this.name}] Service Unavailable (503)`);
        console.error(
          `  -> Jira may be under maintenance, retry in a few minutes`
        );
        break;

      default:
        console.error(`[${this.name}] HTTP ${status} on ${url}`);
        if (errorDetails?.errorMessages) {
          console.error(`  -> ${errorDetails.errorMessages.join(', ')}`);
        }
    }
  }

  /**
   * Fetch all pages of results using Jira-style pagination
   * Ported from em-playbook's get_all_pages() method
   */
  async getAllPages<T>(
    path: string,
    params: Record<string, any> = {},
    itemsKey: string = 'issues',
    pageSize: number = jiraConfig.defaults.maxResults
  ): Promise<T[]> {
    const allItems: T[] = [];
    let startAt = 0;

    while (true) {
      const data = await this.get<any>(path, {
        ...params,
        startAt,
        maxResults: pageSize,
      });

      if (!data || !data[itemsKey]) {
        break;
      }

      allItems.push(...data[itemsKey]);

      // Check if we've fetched all results
      if (data.startAt + data.maxResults >= data.total) {
        break;
      }

      startAt += pageSize;
    }

    return allItems;
  }

  /**
   * Retry a request with exponential backoff for transient errors
   * Returns null if all retries fail
   */
  async withRetry<T>(
    operation: () => Promise<T | null>,
    attempts: number = jiraConfig.defaults.retryAttempts
  ): Promise<T | null> {
    for (let i = 0; i < attempts; i++) {
      const result = await operation();

      if (result !== null) {
        return result;
      }

      if (i < attempts - 1) {
        const delay = jiraConfig.defaults.retryDelay * Math.pow(2, i);
        console.error(`  -> Retrying in ${delay}ms... (attempt ${i + 2}/${attempts})`);
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }

    return null;
  }
}
