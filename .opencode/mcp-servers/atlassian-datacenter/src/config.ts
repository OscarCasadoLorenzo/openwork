/**
 * Instance-specific configuration for Jira custom fields and mappings.
 * This file is USER-EDITABLE and should be customized for your Jira instance.
 *
 * To discover your custom field IDs, run:
 *   pnpm tsx scripts/discover-fields.ts PROJ-123
 */

import type { JiraIssue } from './types.js';

export const jiraConfig = {
  /**
   * Custom field ID mappings
   * Run GET /rest/api/2/field on your Jira instance to discover these IDs
   */
  fields: {
    // Epic Link (standard custom field)
    epicLink: 'customfield_10014',

    // Story Points (try multiple field IDs for Server vs Cloud compatibility)
    storyPoints: [
      'customfield_10003', // Jira Server (common)
      'customfield_10016', // Jira Cloud
      'customfield_10028', // Other variants
    ],

    // Sprint (try multiple field IDs)
    sprint: [
      'customfield_10600', // Jira Server (Greenhopper raw string)
      'customfield_10020', // Jira Cloud (list of sprint objects)
    ],

    // Add your instance's custom fields here:
    // team: "customfield_14900",
    // targetEndDate: "customfield_14903",
    // ragStatus: "customfield_11608",
  },

  /**
   * API request defaults
   */
  defaults: {
    maxResults: 100,   // Default page size for pagination
    timeout: 20000,    // 20 seconds (matches em-playbook)
    retryAttempts: 2,  // Retry transient errors
    retryDelay: 1000,  // 1 second between retries
  },
} as const;

/**
 * Get the value of a custom field from an issue, with fallback support.
 * If the field is configured with multiple IDs, try each until a value is found.
 */
export function getFieldValue(
  issue: JiraIssue,
  logicalName: keyof typeof jiraConfig.fields
): any {
  const fieldIds = jiraConfig.fields[logicalName];
  const ids = Array.isArray(fieldIds) ? fieldIds : [fieldIds];

  for (const id of ids) {
    const value = issue.fields[id];
    if (value !== undefined && value !== null) {
      return value;
    }
  }

  return null;
}

/**
 * Get the custom field ID(s) for a logical field name
 */
export function getFieldId(logicalName: keyof typeof jiraConfig.fields): string | readonly string[] {
  return jiraConfig.fields[logicalName];
}
