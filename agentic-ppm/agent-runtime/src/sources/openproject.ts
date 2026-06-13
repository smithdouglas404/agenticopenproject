/**
 * OpenProject source adapter — wraps the existing discoverer + APIv3 client so
 * OpenProject is just another spoke on the hub (no special-casing in the studio).
 *
 * discoverSchema reuses src/openproject/schema.ts (standard + custom fields).
 * applyUpdate writes scalar attributes back via a lock-version-aware PATCH, and
 * echo-guards the write by stamping the sync-source custom field (when configured)
 * so our own webhook ignores the change — preserving the no-self-echo guarantee.
 */
import { config } from '../config.js';
import { getOpenProjectClient } from '../openproject/client.js';
import { discoverSchema } from '../openproject/schema.js';
import type { AttributeDescriptor } from '../mapping/types.js';
import type { ConnectionStatus, SourceAdapter, WriteResult } from './types.js';

const SOURCE = 'openproject';

/** Link-typed OpenProject attributes need an href payload, not a scalar — skip on write for now. */
const LINK_FIELDS = new Set(['status', 'priority', 'type', 'assignee', 'responsible', 'version', 'category']);

export class OpenProjectAdapter implements SourceAdapter {
  readonly id = SOURCE;
  readonly label = 'OpenProject';
  readonly kind = 'pm' as const;

  isConfigured(): boolean {
    return Boolean(config.openproject.baseUrl && config.openproject.apiKey);
  }

  discoverSchema(): Promise<AttributeDescriptor[]> {
    return discoverSchema().catch(() => []);
  }

  async applyUpdate(objectId: string, fields: Record<string, unknown>): Promise<WriteResult> {
    if (!this.isConfigured()) return { ok: false, source: SOURCE, objectId, error: 'openproject not configured' };
    const wpId = Number(String(objectId).replace(/^op-wp-/, ''));
    if (!Number.isFinite(wpId)) return { ok: false, source: SOURCE, objectId, error: `not a work-package id: ${objectId}` };

    // Only scalar / custom-field attributes are written directly; link fields
    // (status/priority/…) need href resolution and are out of scope for v1.
    const scalar: Record<string, unknown> = {};
    const skipped: string[] = [];
    for (const [k, v] of Object.entries(fields)) {
      if (LINK_FIELDS.has(k)) skipped.push(k);
      else scalar[k] = v;
    }
    // Echo guard: stamp our sync source so the inbound webhook ignores this write.
    if (config.openproject.customFieldSyncSource) {
      scalar[config.openproject.customFieldSyncSource] = config.openproject.syncSource;
    }
    if (Object.keys(scalar).length === 0) {
      return { ok: false, source: SOURCE, objectId, error: `only link fields given (${skipped.join(', ')}); not writable in v1` };
    }
    try {
      await getOpenProjectClient().patchWorkPackage(wpId, scalar);
      const applied = Object.keys(scalar).filter((k) => k !== config.openproject.customFieldSyncSource);
      return {
        ok: true,
        source: SOURCE,
        objectId,
        applied,
        detail: skipped.length ? `updated; skipped link fields: ${skipped.join(', ')}` : 'work package updated',
      };
    } catch (err) {
      return { ok: false, source: SOURCE, objectId, error: err instanceof Error ? err.message : String(err) };
    }
  }

  async testConnection(): Promise<ConnectionStatus> {
    const conn = await getOpenProjectClient().testConnection();
    return conn.connected
      ? { connected: true, detail: `${conn.instanceName ?? 'instance'} (core ${conn.version ?? '?'})` }
      : { connected: false, error: conn.error };
  }
}
