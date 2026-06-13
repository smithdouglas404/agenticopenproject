/**
 * ServiceNow source adapter.
 *
 * Discovery: GET /api/now/table/sys_dictionary?sysparm_query=name=<table> returns
 * the column dictionary (element, column_label, internal_type) for a table (default
 * "incident"); we map internal_type onto our AttributeType. Write-back: PATCH
 * /api/now/table/<table>/<sys_id> { field: value }. Auth: Basic base64(user:password).
 *
 * Config (env): SERVICENOW_INSTANCE_URL, SERVICENOW_USER, SERVICENOW_PASSWORD,
 * SERVICENOW_TABLE (default "incident"). Unconfigured ⇒ empty schema + not-connected;
 * never throws. Live calls untested here — they follow the documented Table API.
 */
import { config } from '../config.js';
import type { AttributeDescriptor, AttributeType } from '../mapping/types.js';
import { basicAuth, httpJson, type ConnectionStatus, type SourceAdapter, type WriteResult } from './types.js';

const SOURCE = 'servicenow';

/** ServiceNow dictionary internal_type → our AttributeType. */
function mapSnType(internalType: string | undefined, name: string): AttributeType {
  const t = (internalType ?? '').toLowerCase();
  if (/percent/i.test(name)) return 'percentage';
  if (t === 'integer' || t === 'decimal' || t === 'float' || t === 'longint') return 'number';
  if (t === 'currency' || t === 'price') return 'currency';
  if (t === 'glide_date' || t === 'glide_date_time' || t === 'due_date') return 'date';
  if (t === 'boolean') return 'boolean';
  if (t === 'choice') return 'enum';
  if (t === 'reference') return 'relation';
  if (t === 'glide_duration') return 'duration';
  if (t === 'user_image' || t === 'user_input') return 'user';
  return 'string';
}

export class ServiceNowAdapter implements SourceAdapter {
  readonly id = SOURCE;
  readonly label = 'ServiceNow';
  readonly kind = 'itsm' as const;

  private get cfg() {
    return config.sources.servicenow;
  }

  private get table(): string {
    return this.cfg.table || 'incident';
  }

  isConfigured(): boolean {
    return Boolean(this.cfg.instanceUrl && this.cfg.user && this.cfg.password);
  }

  private authHeaders(): Record<string, string> {
    return { Authorization: basicAuth(this.cfg.user, this.cfg.password) };
  }

  async discoverSchema(): Promise<AttributeDescriptor[]> {
    if (!this.isConfigured()) return [];
    const base = this.cfg.instanceUrl.replace(/\/$/, '');
    const q = `sysparm_query=name=${encodeURIComponent(this.table)}^active=true&sysparm_fields=element,column_label,internal_type`;
    const r = await httpJson<{ result?: Array<{ element: string; column_label?: string; internal_type?: string | { value?: string } }> }>(
      `${base}/api/now/table/sys_dictionary?${q}`,
      { headers: this.authHeaders() },
    );
    const cols = r.ok ? r.data?.result ?? [] : [];
    return cols
      .filter((c) => c.element)
      .map((c) => {
        const internal = typeof c.internal_type === 'object' ? c.internal_type?.value : c.internal_type;
        return {
          key: c.element,
          label: c.column_label || c.element,
          type: mapSnType(internal, c.element),
          source: SOURCE,
          custom: c.element.startsWith('u_'), // ServiceNow custom columns are u_*
        } satisfies AttributeDescriptor;
      });
  }

  async applyUpdate(objectId: string, fields: Record<string, unknown>): Promise<WriteResult> {
    if (!this.isConfigured()) return { ok: false, source: SOURCE, objectId, error: 'servicenow not configured' };
    const base = this.cfg.instanceUrl.replace(/\/$/, '');
    const r = await httpJson(`${base}/api/now/table/${encodeURIComponent(this.table)}/${encodeURIComponent(objectId)}`, {
      method: 'PATCH',
      headers: this.authHeaders(),
      body: fields,
    });
    if (!r.ok) return { ok: false, source: SOURCE, objectId, error: `HTTP ${r.status}: ${r.text.slice(0, 200)}` };
    return { ok: true, source: SOURCE, objectId, applied: Object.keys(fields), detail: `servicenow ${this.table} updated` };
  }

  async testConnection(): Promise<ConnectionStatus> {
    if (!this.isConfigured()) {
      return { connected: false, detail: 'SERVICENOW_INSTANCE_URL / USER / PASSWORD unset' };
    }
    const base = this.cfg.instanceUrl.replace(/\/$/, '');
    const r = await httpJson(`${base}/api/now/table/${encodeURIComponent(this.table)}?sysparm_limit=1`, {
      headers: this.authHeaders(),
    });
    return r.ok ? { connected: true, detail: `${this.table} @ ${base}` } : { connected: false, error: `HTTP ${r.status}` };
  }
}
