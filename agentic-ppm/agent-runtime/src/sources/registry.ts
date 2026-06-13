/**
 * Source adapter registry — the hub's list of spokes.
 *
 * One place that knows every source the universal mapper can map. Adding a source
 * is registering its adapter here (config, not scattered code). Consumers ask the
 * registry for "the adapter for source X" (discovery, write-back) or "what sources
 * exist + are they configured" (the studio's source selector + health surface).
 */
import type { SourceAdapter, SourceInfo } from './types.js';
import { OpenProjectAdapter } from './openproject.js';
import { JiraAdapter } from './jira.js';
import { AdoAdapter } from './ado.js';
import { ServiceNowAdapter } from './servicenow.js';
import { McpAdapter } from './mcp.js';

/** Instantiated once; adapters are cheap and read config lazily per call. */
const ADAPTERS: SourceAdapter[] = [
  new OpenProjectAdapter(),
  new JiraAdapter(),
  new AdoAdapter(),
  new ServiceNowAdapter(),
  new McpAdapter(),
];

const BY_ID = new Map<string, SourceAdapter>(ADAPTERS.map((a) => [a.id, a]));

/** The adapter for a source id, or undefined if unknown. */
export function getAdapter(source: string): SourceAdapter | undefined {
  return BY_ID.get(source);
}

/** All registered sources with their configured flag, for `GET /api/sources`. */
export function listSources(): SourceInfo[] {
  return ADAPTERS.map((a) => ({ id: a.id, label: a.label, kind: a.kind, configured: a.isConfigured() }));
}

/** Discover a source's schema through its adapter (or [] for an unknown source). */
export function discoverSchemaFor(source: string): Promise<import('../mapping/types.js').AttributeDescriptor[]> {
  const adapter = getAdapter(source);
  return adapter ? adapter.discoverSchema() : Promise.resolve([]);
}
