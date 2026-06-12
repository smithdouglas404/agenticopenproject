/**
 * Minimal OpenProject APIv3 shapes used by the runtime.
 * Lifted/trimmed from DOSv2 server/mcp/OpenProjectService.ts and server/services/openproject/types.ts.
 */

export interface OpenProjectProject {
  id: number;
  identifier: string;
  name: string;
  description?: { raw: string };
  active?: boolean;
  _links?: { parent?: { href?: string } };
}

export interface OpenProjectWorkPackage {
  id?: number;
  subject: string;
  description?: { raw: string; html?: string };
  startDate?: string;
  dueDate?: string;
  estimatedTime?: string;
  spentTime?: string;
  percentageDone?: number;
  lockVersion?: number;
  updatedAt?: string;
  _links?: {
    type?: { href?: string; title?: string };
    status?: { href?: string; title?: string };
    priority?: { href?: string; title?: string };
    assignee?: { href?: string; title?: string };
    project?: { href?: string; title?: string };
    version?: { href?: string; title?: string };
  };
  // Custom fields arrive as customField_<name> on the flattened payload.
  [key: string]: unknown;
}

/**
 * A work-package relation (GET /api/v3/relations). `type` is OpenProject's
 * native relation kind (follows | precedes | blocks | blocked | relates |
 * duplicates | duplicated | includes | partof | requires | required).
 */
export interface OpenProjectRelation {
  id: number;
  type: string;
  _links?: {
    from?: { href?: string; title?: string };
    to?: { href?: string; title?: string };
  };
}

/** A project version/release (GET /api/v3/projects/{id}/versions). */
export interface OpenProjectVersion {
  id: number;
  name: string;
  status?: string; // open | locked | closed
  startDate?: string;
  endDate?: string;
  _links?: { definingProject?: { href?: string; title?: string } };
}

/** A time entry (GET /api/v3/time_entries). `hours` is ISO 8601, e.g. PT8H. */
export interface OpenProjectTimeEntry {
  id: number;
  hours?: string;
  spentOn?: string;
  _links?: {
    workPackage?: { href?: string; title?: string };
    project?: { href?: string; title?: string };
    user?: { href?: string; title?: string };
    activity?: { href?: string; title?: string };
  };
}

export interface OpenProjectConnection {
  connected: boolean;
  version?: string;
  instanceName?: string;
  error?: string;
}
