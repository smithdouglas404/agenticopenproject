/**
 * Source adapters — the SPOKE contract for the universal mapper.
 *
 * Architecture truth (docs/ONTOLOGY_MAPPING_STUDIO.md): the ontology (FalkorDB)
 * is the HUB. Every source — OpenProject, Jira, Azure DevOps, ServiceNow, an MCP
 * server — maps ONCE into the ontology via an adapter, and every consumer (Mastra
 * agents, widgets, rules, dashboards) reads ONCE from the ontology. That is N + M
 * integrations, not N × M.
 *
 * An adapter answers three questions for its source, deterministically (no LLM):
 *   1. discoverSchema()  — "what attributes does this source have?" (the SOURCE
 *      side of the mapper; the studio maps these onto ontology properties).
 *   2. applyUpdate()     — "write this value back to the source" (bidirectional
 *      edit; optional per source, echo-guarded where the source feeds us back).
 *   3. testConnection()  — "are we wired to this source?" (health surface).
 *
 * Adapters are CONFIG, not hard-wired: each reads its own creds from config and
 * reports `configured`. An unconfigured adapter degrades to an empty schema and a
 * not-connected status — it never throws into the studio.
 */
import type { AttributeDescriptor } from '../mapping/types.js';

/** A connectable category, used only for grouping/labels in the UI. */
export type SourceKind = 'pm' | 'itsm' | 'mcp';

/** What `GET /api/sources` lists for the studio's source selector. */
export interface SourceInfo {
  id: string;
  label: string;
  kind: SourceKind;
  /** True when the adapter has the credentials/URL it needs to reach the source. */
  configured: boolean;
}

/** Result of a write-back to a source object. */
export interface WriteResult {
  ok: boolean;
  source: string;
  objectId: string;
  /** Fields actually applied (source-native keys). */
  applied?: string[];
  detail?: string;
  error?: string;
}

/** A connectivity probe result. */
export interface ConnectionStatus {
  connected: boolean;
  detail?: string;
  error?: string;
}

/**
 * One source spoke. discoverSchema is required (it is the whole point of the
 * mapper); applyUpdate/testConnection are optional capabilities a source may add.
 */
export interface SourceAdapter {
  readonly id: string;
  readonly label: string;
  readonly kind: SourceKind;

  /** Whether this adapter has the config/creds it needs to talk to its source. */
  isConfigured(): boolean;

  /**
   * Discover the source's attribute set (standard + custom). MUST NOT throw —
   * degrade to [] (or a known standard set) on any failure, like the OpenProject
   * discoverer does, so the studio always renders.
   */
  discoverSchema(): Promise<AttributeDescriptor[]>;

  /**
   * Write source-native field values back to one object (the bidirectional edit
   * path). The caller has already reverse-mapped ontology props → source keys and
   * applied reverse transforms; the adapter just talks to the source API. Optional.
   */
  applyUpdate?(objectId: string, fields: Record<string, unknown>): Promise<WriteResult>;

  /** Lightweight connectivity check for the health surface. Optional. */
  testConnection?(): Promise<ConnectionStatus>;
}

/** Shared small fetch helper for HTTP adapters: JSON in/out, bounded, never hangs. */
export async function httpJson<T = any>(
  url: string,
  init: {
    method?: string;
    headers?: Record<string, string>;
    body?: unknown;
    /** Send/accept the JSON-Patch content type (Azure DevOps). */
    timeoutMs?: number;
  } = {},
): Promise<{ ok: boolean; status: number; data: T | null; text: string }> {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    ...(init.headers ?? {}),
  };
  if (init.body !== undefined && !headers['Content-Type']) headers['Content-Type'] = 'application/json';
  let res: Response;
  try {
    res = await fetch(url, {
      method: init.method ?? 'GET',
      headers,
      body: init.body !== undefined ? (typeof init.body === 'string' ? init.body : JSON.stringify(init.body)) : undefined,
      signal: AbortSignal.timeout(init.timeoutMs ?? 15_000),
    });
  } catch (err) {
    return { ok: false, status: 0, data: null, text: err instanceof Error ? err.message : String(err) };
  }
  const text = await res.text().catch(() => '');
  let data: T | null = null;
  try {
    data = text ? (JSON.parse(text) as T) : null;
  } catch {
    /* non-JSON body */
  }
  return { ok: res.ok, status: res.status, data, text };
}

/** Basic-auth header value from a user:secret pair. */
export function basicAuth(user: string, secret: string): string {
  return `Basic ${Buffer.from(`${user}:${secret}`).toString('base64')}`;
}
