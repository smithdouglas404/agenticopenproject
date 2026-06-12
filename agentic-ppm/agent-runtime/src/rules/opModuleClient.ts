/**
 * OpenProject `agentic_ppm` module client — rules + native alerts endpoints.
 *
 * WHAT: Thin fetch wrappers for the two module endpoints the rules engine talks to:
 *   GET  /agentic_ppm/api/rules.json   (and per-project)  -> {rules: Rule[]}
 *   POST /agentic_ppm/api/alerts.json   -> persists an OpenProject-native alert
 * WHY: Kept SEPARATE from src/openproject/client.ts (the APIv3 client) so the core
 * client stays focused on /api/v3 — these hit the module's own routes, with the
 * module's own auth (X-OP-Rules-Token) plus the same basic auth (belt + suspenders).
 */
import { config } from '../config.js';
import type { Rule, RuleSeverity } from './types.js';

/** Payload for an OpenProject-native rule alert (alerts.json contract). */
export interface RuleAlertPayload {
  agent: string;
  ontology_subject: string;
  title: string;
  body: string;
  severity: RuleSeverity;
  confidence: number;
  evidence: {
    rule_id: number;
    metric: string;
    observed_value: number | string;
    threshold: number | null;
    operator: string;
  };
  project_id?: number;
  work_package_id?: number;
}

function baseUrl(): string {
  return config.openproject.baseUrl.replace(/\/$/, '');
}

/** Auth headers: module token AND basic auth apikey:<key> (belt and suspenders). */
function headers(): Record<string, string> {
  const auth = Buffer.from(`apikey:${config.openproject.apiKey}`).toString('base64');
  const h: Record<string, string> = {
    Authorization: `Basic ${auth}`,
    'Content-Type': 'application/json',
    Accept: 'application/json',
  };
  if (config.rules.apiToken) h['X-OP-Rules-Token'] = config.rules.apiToken;
  return h;
}

/**
 * GET the module's rules.json. Global feed by default; pass an OpenProject project
 * id for the per-project feed. Throws on a non-2xx so the loader can fall back to
 * its cache — the loader, not this method, owns the degrade-gracefully policy.
 */
export async function getRulesJson(projectId?: number): Promise<Rule[]> {
  const path =
    projectId != null
      ? `/projects/${projectId}/agentic_ppm/api/rules.json`
      : `/agentic_ppm/api/rules.json`;
  const res = await fetch(`${baseUrl()}${path}`, { method: 'GET', headers: headers() });
  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    throw new Error(`rules.json GET ${path} -> ${res.status}: ${detail.slice(0, 200)}`);
  }
  const data = (await res.json()) as { rules?: Rule[] };
  return data.rules ?? [];
}

/**
 * POST a breach to the module's alerts.json so it lands in OpenProject's native
 * rules inbox. Best-effort: returns false on failure (caller logs and continues).
 */
export async function postRuleAlert(payload: RuleAlertPayload): Promise<boolean> {
  try {
    const res = await fetch(`${baseUrl()}/agentic_ppm/api/alerts.json`, {
      method: 'POST',
      headers: headers(),
      body: JSON.stringify(payload),
    });
    if (!res.ok) {
      const detail = await res.text().catch(() => '');
      console.warn(`[rules] alerts.json POST -> ${res.status}: ${detail.slice(0, 200)}`);
      return false;
    }
    return true;
  } catch (err) {
    console.warn(`[rules] alerts.json POST failed: ${(err as Error).message}`);
    return false;
  }
}
