/**
 * MCP (Model Context Protocol) source adapter — the "any tool/data server is a
 * spoke" case (docs/ONTOLOGY_MAPPING_STUDIO.md §4).
 *
 *   MCP resources → ontology objects   (discoverSchema samples a resource's shape)
 *   MCP tools     → ontology actions    (applyUpdate calls a configured update tool)
 *
 * Transport: a MINIMAL JSON-RPC 2.0 client over streamable HTTP (POST the endpoint
 * with Accept: application/json, text/event-stream; honor an Mcp-Session-Id). This
 * deliberately avoids adding the MCP SDK dependency to keep the runtime lean and
 * the CI smoke test green. It is best-effort and untested against a live server
 * here — pure-SSE-only servers may need the SDK; wire that in if required.
 *
 * Config (env): MCP_SERVER_URL, MCP_HEADERS (JSON), MCP_OBJECT_RESOURCE (a uri to
 * sample for the object schema), MCP_UPDATE_TOOL (tool name used for write-back).
 * Unconfigured ⇒ empty schema + not-connected; never throws.
 */
import { config } from '../config.js';
import type { AttributeDescriptor, AttributeType } from '../mapping/types.js';
import type { ConnectionStatus, SourceAdapter, WriteResult } from './types.js';

const SOURCE = 'mcp';

interface McpResource { uri: string; name?: string; mimeType?: string; description?: string }
interface McpTool { name: string; description?: string; inputSchema?: { properties?: Record<string, any> } }

/** Infer an AttributeType from a sampled JSON value. */
function inferType(value: unknown, key: string): AttributeType {
  if (/percent|progress/i.test(key)) return 'percentage';
  if (typeof value === 'number') return 'number';
  if (typeof value === 'boolean') return 'boolean';
  if (Array.isArray(value)) return 'list';
  if (typeof value === 'string') {
    if (/^\d{4}-\d{2}-\d{2}/.test(value)) return 'date';
    return 'string';
  }
  if (value && typeof value === 'object') return 'relation';
  return 'string';
}

/** Map a JSON-schema property type (from a tool inputSchema) to AttributeType. */
function mapJsonSchemaType(prop: any, key: string): AttributeType {
  const t = Array.isArray(prop?.type) ? prop.type[0] : prop?.type;
  if (/percent|progress/i.test(key)) return 'percentage';
  if (t === 'number' || t === 'integer') return 'number';
  if (t === 'boolean') return 'boolean';
  if (t === 'array') return 'list';
  if (prop?.enum) return 'enum';
  if (prop?.format === 'date' || prop?.format === 'date-time') return 'date';
  return 'string';
}

export class McpAdapter implements SourceAdapter {
  readonly id = SOURCE;
  readonly label = 'MCP server';
  readonly kind = 'mcp' as const;

  private sessionId: string | null = null;
  private rpcId = 0;

  private get cfg() {
    return config.sources.mcp;
  }

  isConfigured(): boolean {
    return Boolean(this.cfg.url);
  }

  private headers(): Record<string, string> {
    const h: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'application/json, text/event-stream',
      ...this.cfg.headers,
    };
    if (this.sessionId) h['Mcp-Session-Id'] = this.sessionId;
    return h;
  }

  /** Minimal JSON-RPC call. Returns result or throws (callers catch + degrade). */
  private async rpc<T = any>(method: string, params?: unknown): Promise<T> {
    const res = await fetch(this.cfg.url, {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify({ jsonrpc: '2.0', id: ++this.rpcId, method, params }),
      signal: AbortSignal.timeout(15_000),
    });
    const sid = res.headers.get('mcp-session-id');
    if (sid) this.sessionId = sid;
    const text = await res.text();
    // streamable HTTP may answer as SSE ("event: message\ndata: {...}") — pull the JSON.
    const jsonText = text.includes('data:') ? text.split(/data:\s*/).pop()!.trim() : text;
    let parsed: any = null;
    try {
      parsed = jsonText ? JSON.parse(jsonText) : null;
    } catch {
      parsed = null;
    }
    if (!res.ok || parsed?.error) {
      throw new Error(parsed?.error?.message ?? `MCP ${method} HTTP ${res.status}`);
    }
    return parsed?.result as T;
  }

  /** Best-effort handshake; safe to call repeatedly. */
  private async ensureInitialized(): Promise<void> {
    if (this.sessionId) return;
    await this.rpc('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'agentic-ppm-agent-runtime', version: '0.1.0' },
    }).catch(() => undefined);
  }

  async listResources(): Promise<McpResource[]> {
    if (!this.isConfigured()) return [];
    try {
      await this.ensureInitialized();
      const r = await this.rpc<{ resources?: McpResource[] }>('resources/list');
      return r?.resources ?? [];
    } catch {
      return [];
    }
  }

  /** MCP tools → ontology actions. */
  async listTools(): Promise<McpTool[]> {
    if (!this.isConfigured()) return [];
    try {
      await this.ensureInitialized();
      const r = await this.rpc<{ tools?: McpTool[] }>('tools/list');
      return r?.tools ?? [];
    } catch {
      return [];
    }
  }

  /**
   * MCP resources → ontology objects. Discover attributes by sampling: read the
   * configured object resource (or the first listed resource) and expose its JSON
   * keys as attributes. If no readable resource, fall back to the configured
   * update tool's inputSchema properties (tools → action params).
   */
  async discoverSchema(): Promise<AttributeDescriptor[]> {
    if (!this.isConfigured()) return [];
    try {
      await this.ensureInitialized();
      const resources = await this.listResources();
      const target = this.cfg.objectResource
        ? resources.find((r) => r.uri === this.cfg.objectResource) ?? { uri: this.cfg.objectResource }
        : resources[0];

      if (target?.uri) {
        const read = await this.rpc<{ contents?: Array<{ text?: string; json?: unknown }> }>('resources/read', {
          uri: target.uri,
        }).catch(() => null);
        const first = read?.contents?.[0];
        let obj: Record<string, unknown> | null = null;
        if (first?.json && typeof first.json === 'object') obj = first.json as Record<string, unknown>;
        else if (typeof first?.text === 'string') {
          try {
            const j = JSON.parse(first.text);
            if (j && typeof j === 'object' && !Array.isArray(j)) obj = j;
            else if (Array.isArray(j) && j[0] && typeof j[0] === 'object') obj = j[0];
          } catch {
            /* not JSON */
          }
        }
        if (obj) {
          return Object.entries(obj).map(([key, value]) => ({
            key,
            label: key,
            type: inferType(value, key),
            source: SOURCE,
            custom: false,
          }));
        }
      }

      // Fallback: derive attributes from the update tool's input schema.
      const tools = await this.listTools();
      const updateTool = tools.find((t) => t.name === this.cfg.updateTool) ?? tools[0];
      const props = updateTool?.inputSchema?.properties ?? {};
      return Object.entries(props).map(([key, prop]) => ({
        key,
        label: (prop as any)?.title ?? key,
        type: mapJsonSchemaType(prop, key),
        source: SOURCE,
        custom: false,
      }));
    } catch {
      return [];
    }
  }

  /** Write-back via a configured MCP tool (tools → actions). */
  async applyUpdate(objectId: string, fields: Record<string, unknown>): Promise<WriteResult> {
    if (!this.isConfigured()) return { ok: false, source: SOURCE, objectId, error: 'mcp not configured' };
    if (!this.cfg.updateTool) {
      return { ok: false, source: SOURCE, objectId, error: 'MCP_UPDATE_TOOL not set (no write-back tool)' };
    }
    try {
      await this.ensureInitialized();
      await this.rpc('tools/call', { name: this.cfg.updateTool, arguments: { id: objectId, ...fields } });
      return { ok: true, source: SOURCE, objectId, applied: Object.keys(fields), detail: `mcp tool ${this.cfg.updateTool}` };
    } catch (err) {
      return { ok: false, source: SOURCE, objectId, error: err instanceof Error ? err.message : String(err) };
    }
  }

  async testConnection(): Promise<ConnectionStatus> {
    if (!this.isConfigured()) return { connected: false, detail: 'MCP_SERVER_URL unset' };
    try {
      await this.ensureInitialized();
      const tools = await this.listTools();
      const resources = await this.listResources();
      return { connected: true, detail: `${tools.length} tool(s), ${resources.length} resource(s) @ ${this.cfg.url}` };
    } catch (err) {
      return { connected: false, error: err instanceof Error ? err.message : String(err) };
    }
  }
}
