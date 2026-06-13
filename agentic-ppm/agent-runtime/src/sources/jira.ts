/**
 * Jira (Cloud) source adapter.
 *
 * Discovery: GET /rest/api/3/field returns every field (system + custom) with a
 * `schema.type` we map onto our AttributeType. Write-back: PUT /rest/api/3/issue/
 * :key { fields: {...} }. Auth: Basic base64(email:apiToken) (Jira Cloud API token).
 *
 * Config (env): JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN. Unconfigured ⇒ empty
 * schema + not-connected; never throws into the studio. Live calls are untested
 * here (no instance) — they follow the documented Jira Cloud REST contract.
 */
import { config } from '../config.js';
import type { AttributeDescriptor, AttributeType } from '../mapping/types.js';
import { basicAuth, httpJson, type ConnectionStatus, type SourceAdapter, type WriteResult } from './types.js';

const SOURCE = 'jira';

/** Jira `schema.type`/`schema.items` → our AttributeType. */
function mapJiraType(schema: { type?: string; items?: string; custom?: string } | undefined, name: string): AttributeType {
  const t = (schema?.type ?? '').toLowerCase();
  if (/progress|percent/i.test(name)) return 'percentage';
  if (t === 'number') return 'number';
  if (t === 'date' || t === 'datetime') return 'date';
  if (t === 'user') return 'user';
  if (t === 'array') return 'list';
  if (t === 'option' || t === 'priority' || t === 'status' || t === 'resolution' || t === 'issuetype' || t === 'version')
    return 'enum';
  if (t === 'timetracking') return 'duration';
  if (t === 'issuelink' || t === 'project') return 'relation';
  return 'string';
}

export class JiraAdapter implements SourceAdapter {
  readonly id = SOURCE;
  readonly label = 'Jira';
  readonly kind = 'pm' as const;

  private get cfg() {
    return config.sources.jira;
  }

  isConfigured(): boolean {
    return Boolean(this.cfg.baseUrl && this.cfg.email && this.cfg.apiToken);
  }

  private authHeaders(): Record<string, string> {
    return { Authorization: basicAuth(this.cfg.email, this.cfg.apiToken) };
  }

  async discoverSchema(): Promise<AttributeDescriptor[]> {
    if (!this.isConfigured()) return [];
    const base = this.cfg.baseUrl.replace(/\/$/, '');
    const r = await httpJson<Array<{ id: string; key?: string; name: string; custom?: boolean; schema?: any }>>(
      `${base}/rest/api/3/field`,
      { headers: this.authHeaders() },
    );
    if (!r.ok || !Array.isArray(r.data)) return [];
    return r.data.map((f) => ({
      key: f.key ?? f.id,
      label: f.name ?? f.key ?? f.id,
      type: mapJiraType(f.schema, f.name ?? ''),
      source: SOURCE,
      custom: Boolean(f.custom ?? f.schema?.custom),
    }));
  }

  async applyUpdate(objectId: string, fields: Record<string, unknown>): Promise<WriteResult> {
    if (!this.isConfigured()) {
      return { ok: false, source: SOURCE, objectId, error: 'jira not configured' };
    }
    const base = this.cfg.baseUrl.replace(/\/$/, '');
    const r = await httpJson(`${base}/rest/api/3/issue/${encodeURIComponent(objectId)}`, {
      method: 'PUT',
      headers: this.authHeaders(),
      body: { fields },
    });
    if (!r.ok) return { ok: false, source: SOURCE, objectId, error: `HTTP ${r.status}: ${r.text.slice(0, 200)}` };
    return { ok: true, source: SOURCE, objectId, applied: Object.keys(fields), detail: 'jira issue updated' };
  }

  async testConnection(): Promise<ConnectionStatus> {
    if (!this.isConfigured()) return { connected: false, detail: 'JIRA_BASE_URL / JIRA_EMAIL / JIRA_API_TOKEN unset' };
    const base = this.cfg.baseUrl.replace(/\/$/, '');
    const r = await httpJson<{ displayName?: string; emailAddress?: string }>(`${base}/rest/api/3/myself`, {
      headers: this.authHeaders(),
    });
    return r.ok
      ? { connected: true, detail: `as ${r.data?.displayName ?? r.data?.emailAddress ?? 'user'} @ ${base}` }
      : { connected: false, error: `HTTP ${r.status}` };
  }
}
