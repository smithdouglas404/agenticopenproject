/**
 * Source-adapter registry — one place every source plugs into.
 *
 * NEW BUILD ("Later" feature). Maps an adapter id -> SourceAdapter and exposes a
 * compact list for the studio's source picker. Registered today:
 *   - openproject : wraps the live discoverSchema() (the real, discovered source).
 *   - jira / azuredevops / servicenow : STUB adapters whose discoverSchema()
 *     returns the canonical fields each source carries, DERIVED from the per-source
 *     type maps already in src/ontology/mapping.ts (FIELD_MAPS + TYPE_MAPS). This
 *     lets the studio show their fields and map to the spine WITHOUT live creds.
 *   - any MCP servers configured via config.mcp (resources→objects, tools→actions).
 *
 * The REST stubs are clearly marked TODO for real API wiring; they never need
 * credentials and never throw, so the studio always renders something.
 */
import type { AttributeDescriptor, AttributeType } from '../mapping/types.js';
import type { AdapterSummary, SourceAdapter } from './types.js';
import { discoverSchema } from '../openproject/schema.js';
import { FIELD_MAPS, type SourceSystem } from '../ontology/mapping.js';
import { config } from '../config.js';
import { createMcpAdapter } from './mcp.js';

// ── OpenProject: the one real, discovered source ───────────────────────────
const openprojectAdapter: SourceAdapter = {
  id: 'openproject',
  label: 'OpenProject',
  kind: 'rest',
  discoverSchema: () => discoverSchema(),
};

// ── REST stubs derived from the existing per-source field maps ─────────────
// The spine property a field normalizes onto implies its semantic type, so we
// can derive a representative AttributeDescriptor[] from FIELD_MAPS alone — no
// live API. Real wiring (auth + pull) is the TODO each stub flags.

/** Spine-canonical key -> the AttributeType the studio should treat it as. */
const CANONICAL_TYPE: Record<string, AttributeType> = {
  name: 'string',
  description: 'string',
  status: 'enum',
  priority: 'enum',
  assignee: 'user',
  startDate: 'date',
  endDate: 'date',
  dueDate: 'date',
  progress: 'percentage',
  estimatedHours: 'duration',
  actualHours: 'duration',
  storyPoints: 'number',
};

/** Titleize a native field key for a human label ("short_description" -> "Short Description"). */
function labelize(key: string): string {
  return key
    .replace(/[_-]+/g, ' ')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/\b\w/g, (c) => c.toUpperCase())
    .trim();
}

/**
 * Build a representative AttributeDescriptor[] for a REST source from its
 * FIELD_MAPS entry (native field name -> canonical spine key). TODO: replace with
 * a live schema pull (Jira /field, ADO /fields, ServiceNow sys_dictionary).
 */
function stubSchemaFor(source: SourceSystem): AttributeDescriptor[] {
  const fieldMap = FIELD_MAPS[source] ?? {};
  return Object.entries(fieldMap).map(([nativeKey, canonical]) => ({
    key: nativeKey,
    label: labelize(nativeKey),
    type: CANONICAL_TYPE[canonical as string] ?? 'string',
    source,
    custom: false,
  }));
}

/** Make a read-only REST stub adapter for a known source system. */
function makeRestStub(id: SourceSystem, label: string): SourceAdapter {
  return {
    id,
    label,
    kind: 'rest',
    // TODO: wire the real API (auth + schema discovery). Offline-safe today.
    discoverSchema: async () => stubSchemaFor(id),
  };
}

// ── Registry assembly ───────────────────────────────────────────────────────
const baseAdapters: SourceAdapter[] = [
  openprojectAdapter,
  makeRestStub('jira', 'Jira'),
  makeRestStub('servicenow', 'ServiceNow'),
];

// Azure DevOps isn't a SourceSystem in mapping.ts (no FIELD_MAPS entry), so give
// it a hand-built representative field set in the same spine-canonical shape.
const azureDevOpsAdapter: SourceAdapter = {
  id: 'azuredevops',
  label: 'Azure DevOps',
  kind: 'rest',
  // TODO: wire the real Azure DevOps REST API (work item fields). Offline-safe today.
  discoverSchema: async () => {
    const fields: Array<[string, string, AttributeType]> = [
      ['System.Title', 'Title', 'string'],
      ['System.Description', 'Description', 'string'],
      ['System.State', 'State', 'enum'],
      ['Microsoft.VSTS.Common.Priority', 'Priority', 'enum'],
      ['System.AssignedTo', 'Assigned To', 'user'],
      ['Microsoft.VSTS.Scheduling.StartDate', 'Start Date', 'date'],
      ['Microsoft.VSTS.Scheduling.TargetDate', 'Target Date', 'date'],
      ['Microsoft.VSTS.Scheduling.StoryPoints', 'Story Points', 'number'],
      ['Microsoft.VSTS.Scheduling.RemainingWork', 'Remaining Work', 'duration'],
      ['System.WorkItemType', 'Work Item Type', 'enum'],
    ];
    return fields.map(([key, label, type]) => ({ key, label, type, source: 'azuredevops', custom: false }));
  },
};
baseAdapters.push(azureDevOpsAdapter);

// MCP adapters from config (optional; none configured = none registered).
for (const server of config.mcp.servers) {
  baseAdapters.push(createMcpAdapter(server.url, server.transport));
}

/** All registered adapters, keyed by id. */
export const ADAPTERS: Record<string, SourceAdapter> = Object.fromEntries(
  baseAdapters.map((a) => [a.id, a]),
);

/** Look up an adapter by id, or undefined if not registered. */
export function getAdapter(id: string): SourceAdapter | undefined {
  return ADAPTERS[id];
}

/** Compact list for the studio's source picker (no methods). */
export function listAdapters(): AdapterSummary[] {
  return Object.values(ADAPTERS).map(({ id, label, kind }) => ({ id, label, kind }));
}
