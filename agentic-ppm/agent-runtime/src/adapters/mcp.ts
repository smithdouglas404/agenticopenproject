/**
 * MCP source adapter — a Model Context Protocol server as a mappable source.
 *
 * NEW BUILD ("Later" feature). The PATTERN: an MCP server's RESOURCES become
 * objects/attributes the studio can map onto the spine, and its TOOLS become
 * candidate agent ACTIONS (surfaced via listTools()). This runtime is an MCP
 * *client* (same SDK as src/graph/graphiti.ts); we connect on demand, list
 * resources/tools, and translate them into AttributeDescriptor[] / tool list.
 *
 * Degrades gracefully: an unreachable/empty server yields [] and a warning,
 * NEVER a throw — the mapping routes must stay 200.
 */
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { SSEClientTransport } from '@modelcontextprotocol/sdk/client/sse.js';
import { StreamableHTTPClientTransport } from '@modelcontextprotocol/sdk/client/streamableHttp.js';
import type { AttributeDescriptor, AttributeType } from '../mapping/types.js';
import type { McpToolDescriptor, SourceAdapter } from './types.js';

export type McpTransport = 'sse' | 'http';

/** Short, stable id fragment from a server URL ("mcp:graphiti-mcp"). */
function serverTag(serverUrl: string): string {
  try {
    return new URL(serverUrl).hostname || serverUrl;
  } catch {
    return serverUrl;
  }
}

/** Connect a one-shot MCP client to the server, or null if unreachable. */
async function connect(serverUrl: string, transport: McpTransport): Promise<Client | null> {
  try {
    const url = new URL(serverUrl);
    const t = transport === 'http' ? new StreamableHTTPClientTransport(url) : new SSEClientTransport(url);
    const client = new Client({ name: 'agentic-ppm-mcp-source', version: '0.1.0' }, { capabilities: {} });
    await client.connect(t);
    return client;
  } catch (err: any) {
    console.warn(`[mcp:${serverTag(serverUrl)}] connect failed (${err?.message ?? err}); degrading to empty`);
    return null;
  }
}

/**
 * Best-effort map an MCP resource (and, when exposed, its field/properties
 * schema) onto AttributeDescriptor[]. MCP resources don't mandate a field schema,
 * so the common case is one descriptor per resource (keyed by uri/name). When a
 * JSON-schema-ish `properties` bag is present (some servers attach one), each
 * property becomes its own attribute.
 */
function resourceToAttributes(resource: any, source: string): AttributeDescriptor[] {
  const baseKey = String(resource?.uri ?? resource?.name ?? '').trim();
  if (!baseKey) return [];
  const props = resource?.schema?.properties ?? resource?.properties;
  if (props && typeof props === 'object') {
    return Object.entries(props as Record<string, any>).map(([key, def]) => ({
      key: `${baseKey}.${key}`,
      label: String(def?.title ?? key),
      type: jsonSchemaType(def?.type),
      source,
      custom: true,
    }));
  }
  return [
    {
      key: baseKey,
      label: String(resource?.name ?? baseKey),
      type: 'string',
      source,
      custom: true,
    },
  ];
}

/** JSON-schema primitive -> our AttributeType (loose; defaults to string). */
function jsonSchemaType(t: unknown): AttributeType {
  switch (String(t)) {
    case 'number':
    case 'integer':
      return 'number';
    case 'boolean':
      return 'boolean';
    case 'array':
      return 'list';
    default:
      return 'string';
  }
}

/**
 * Build an MCP-backed SourceAdapter for one server. Lazy + offline-safe: nothing
 * connects until discoverSchema()/listTools() is called, and any failure yields
 * an empty result with a warning.
 */
export function createMcpAdapter(serverUrl: string, transport: McpTransport = 'sse'): SourceAdapter {
  const tag = serverTag(serverUrl);
  const source = `mcp:${tag}`;
  return {
    id: source,
    label: `MCP: ${tag}`,
    kind: 'mcp',

    // resources/list -> AttributeDescriptor[]. If only tools exist, returns [].
    async discoverSchema(): Promise<AttributeDescriptor[]> {
      const client = await connect(serverUrl, transport);
      if (!client) return [];
      try {
        const { resources } = await client.listResources();
        const out: AttributeDescriptor[] = [];
        for (const r of resources ?? []) out.push(...resourceToAttributes(r, source));
        return out;
      } catch (err: any) {
        console.warn(`[mcp:${tag}] resources/list failed (${err?.message ?? err}); returning []`);
        return [];
      } finally {
        await client.close().catch(() => {});
      }
    },

    // tools/list -> tool descriptors (MCP TOOLS as candidate agent ACTIONS).
    async listTools(): Promise<McpToolDescriptor[]> {
      const client = await connect(serverUrl, transport);
      if (!client) return [];
      try {
        const { tools } = await client.listTools();
        return (tools ?? []).map((t) => ({
          name: t.name,
          description: t.description,
          inputSchema: t.inputSchema,
        }));
      } catch (err: any) {
        console.warn(`[mcp:${tag}] tools/list failed (${err?.message ?? err}); returning []`);
        return [];
      } finally {
        await client.close().catch(() => {});
      }
    },
  };
}
