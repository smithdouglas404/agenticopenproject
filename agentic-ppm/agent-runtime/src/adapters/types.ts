/**
 * Pluggable source adapters — the SOURCE side of the universal mapper.
 *
 * NEW BUILD ("Later" feature). The mapping studio was OpenProject-only; this
 * generalizes "source" so any system (Jira, Azure DevOps, ServiceNow, an MCP
 * server, a file) can advertise its attributes, get them mapped onto the spine,
 * and optionally be pulled/written-back. A SourceAdapter is the contract: it
 * reuses the mapping layer's AttributeDescriptor so the studio renders any
 * source's fields uniformly. Everything beyond discoverSchema() is optional —
 * stubs and read-only sources just implement discovery.
 */
import type { AttributeDescriptor } from '../mapping/types.js';

/** How an adapter physically reaches its source. */
export type SourceKind = 'rest' | 'mcp' | 'file';

/** One MCP tool (resources→objects, tools→agent ACTIONS later). */
export interface McpToolDescriptor {
  name: string;
  description?: string;
  inputSchema?: unknown;
}

/**
 * A pluggable source the mapping studio can target. discoverSchema() is the only
 * required method; pulls/writes/MCP-tools are optional capabilities a source
 * advertises by implementing the matching method.
 */
export interface SourceAdapter {
  /** Stable id, e.g. "openproject", "jira", "mcp:graphiti". */
  id: string;
  /** Human label for the studio's source picker. */
  label: string;
  kind: SourceKind;
  /** Advertise the source's attributes as mapping-layer AttributeDescriptors. */
  discoverSchema(): Promise<AttributeDescriptor[]>;
  /** Optional pull of raw objects (for ingest/preview). */
  listObjects?(opts?: { limit?: number }): Promise<Record<string, unknown>[]>;
  /** Optional write-back of changed fields onto a source object. */
  writeBack?(objectId: string, changes: Record<string, unknown>): Promise<void>;
  /** MCP-specific: list the server's tools (so MCP TOOLS can become agent ACTIONS). */
  listTools?(): Promise<McpToolDescriptor[]>;
}

/** The compact descriptor the /api/sources list returns (no methods). */
export interface AdapterSummary {
  id: string;
  label: string;
  kind: SourceKind;
}
