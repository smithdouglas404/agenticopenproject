/**
 * Azure DevOps (Boards) source adapter.
 *
 * Discovery: GET {org}/_apis/wit/fields lists work-item fields with a `type` we
 * map onto our AttributeType. Write-back: PATCH {org}/{project}/_apis/wit/
 * workitems/:id with a JSON-Patch document ([{op:'add', path:'/fields/<ref>',
 * value}]) and Content-Type application/json-patch+json. Auth: Basic base64(":"+PAT).
 *
 * Config (env): ADO_ORG_URL (e.g. https://dev.azure.com/org), ADO_PROJECT, ADO_PAT.
 * Unconfigured ⇒ empty schema + not-connected; never throws. Live calls untested
 * here — they follow the documented Azure DevOps REST contract (api-version 7.0).
 */
import { config } from '../config.js';
import type { AttributeDescriptor, AttributeType } from '../mapping/types.js';
import { basicAuth, httpJson, type ConnectionStatus, type SourceAdapter, type WriteResult } from './types.js';

const SOURCE = 'ado';
const API = 'api-version=7.0';

/** Azure DevOps field `type` → our AttributeType. */
function mapAdoType(adoType: string | undefined, name: string): AttributeType {
  const t = (adoType ?? '').toLowerCase();
  if (/percent|progress/i.test(name)) return 'percentage';
  if (t === 'double' || t === 'integer') return 'number';
  if (t === 'datetime') return 'date';
  if (t === 'boolean') return 'boolean';
  if (t === 'treepath') return 'hierarchy';
  if (t === 'identity') return 'user';
  if (t === 'pickliststring' || t === 'picklistinteger') return 'enum';
  return 'string';
}

export class AdoAdapter implements SourceAdapter {
  readonly id = SOURCE;
  readonly label = 'Azure DevOps';
  readonly kind = 'pm' as const;

  private get cfg() {
    return config.sources.ado;
  }

  isConfigured(): boolean {
    return Boolean(this.cfg.orgUrl && this.cfg.pat);
  }

  private authHeaders(extra?: Record<string, string>): Record<string, string> {
    // Azure DevOps PAT auth = Basic base64(":<pat>").
    return { Authorization: basicAuth('', this.cfg.pat), ...(extra ?? {}) };
  }

  async discoverSchema(): Promise<AttributeDescriptor[]> {
    if (!this.isConfigured()) return [];
    const org = this.cfg.orgUrl.replace(/\/$/, '');
    const r = await httpJson<{ value?: Array<{ referenceName: string; name: string; type?: string }> }>(
      `${org}/_apis/wit/fields?${API}`,
      { headers: this.authHeaders() },
    );
    const fields = r.ok ? r.data?.value ?? [] : [];
    return fields.map((f) => ({
      key: f.referenceName,
      label: f.name ?? f.referenceName,
      type: mapAdoType(f.type, f.name ?? ''),
      source: SOURCE,
      // System.* are standard; everything else (Custom.* / Microsoft.VSTS extensions) is "custom-ish".
      custom: !f.referenceName.startsWith('System.'),
    }));
  }

  async applyUpdate(objectId: string, fields: Record<string, unknown>): Promise<WriteResult> {
    if (!this.isConfigured()) return { ok: false, source: SOURCE, objectId, error: 'ado not configured' };
    const org = this.cfg.orgUrl.replace(/\/$/, '');
    const project = this.cfg.project ? `${encodeURIComponent(this.cfg.project)}/` : '';
    const patch = Object.entries(fields).map(([ref, value]) => ({ op: 'add', path: `/fields/${ref}`, value }));
    const r = await httpJson(`${org}/${project}_apis/wit/workitems/${encodeURIComponent(objectId)}?${API}`, {
      method: 'PATCH',
      headers: this.authHeaders({ 'Content-Type': 'application/json-patch+json' }),
      body: patch,
    });
    if (!r.ok) return { ok: false, source: SOURCE, objectId, error: `HTTP ${r.status}: ${r.text.slice(0, 200)}` };
    return { ok: true, source: SOURCE, objectId, applied: Object.keys(fields), detail: 'ado work item updated' };
  }

  async testConnection(): Promise<ConnectionStatus> {
    if (!this.isConfigured()) return { connected: false, detail: 'ADO_ORG_URL / ADO_PAT unset' };
    const org = this.cfg.orgUrl.replace(/\/$/, '');
    const r = await httpJson(`${org}/_apis/projects?${API}`, { headers: this.authHeaders() });
    return r.ok ? { connected: true, detail: `@ ${org}` } : { connected: false, error: `HTTP ${r.status}` };
  }
}
