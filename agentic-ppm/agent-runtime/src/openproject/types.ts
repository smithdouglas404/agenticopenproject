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
  _links?: {
    type?: { href?: string; title?: string };
    status?: { href?: string; title?: string };
    priority?: { href?: string; title?: string };
    assignee?: { href?: string; title?: string };
    project?: { href?: string; title?: string };
  };
  // Custom fields arrive as customField_<name> on the flattened payload.
  [key: string]: unknown;
}

export interface OpenProjectConnection {
  connected: boolean;
  version?: string;
  instanceName?: string;
  error?: string;
}
