/**
 * Jira API type definitions
 * Based on Jira REST API v2 specification
 */

// Core Jira issue structure
export interface JiraIssue {
  id: string;
  key: string;
  self: string;
  fields: JiraIssueFields;
  renderedFields?: Record<string, any>;
  changelog?: JiraChangelog;
}

export interface JiraIssueFields {
  summary: string;
  description?: string;
  status: JiraStatus;
  assignee?: JiraUser | null;
  reporter?: JiraUser;
  created: string;
  updated: string;
  priority?: JiraPriority;
  labels?: string[];
  components?: JiraComponent[];
  // Custom fields are accessed dynamically
  [customField: string]: any;
}

export interface JiraStatus {
  id: string;
  name: string;
  statusCategory: {
    key: string;
    name: string;
    colorName?: string;
  };
}

export interface JiraUser {
  accountId?: string;
  displayName: string;
  emailAddress?: string;
  active?: boolean;
  // Data Center may use "name" instead of accountId
  name?: string;
}

export interface JiraPriority {
  id: string;
  name: string;
  iconUrl?: string;
}

export interface JiraComponent {
  id: string;
  name: string;
  description?: string;
}

export interface JiraComment {
  id: string;
  author: JiraUser;
  body: string;
  created: string;
  updated: string;
  visibility?: {
    type: string;
    value: string;
  };
}

export interface JiraChangelog {
  startAt: number;
  maxResults: number;
  total: number;
  histories: JiraChangeHistory[];
}

export interface JiraChangeHistory {
  id: string;
  author: JiraUser;
  created: string;
  items: JiraChangeItem[];
}

export interface JiraChangeItem {
  field: string;
  fieldtype: string;
  from?: string;
  fromString?: string;
  to?: string;
  toString?: string;
}

// Search results
export interface JiraSearchResult {
  startAt: number;
  maxResults: number;
  total: number;
  issues: JiraIssue[];
}

// Comments API response
export interface JiraCommentsResponse {
  startAt: number;
  maxResults: number;
  total: number;
  comments: JiraComment[];
}

// Error response structure
export interface JiraErrorResponse {
  errorMessages?: string[];
  errors?: Record<string, string>;
}
