/**
 * Dependency preflight checks, shared by the CLI (`npm run preflight`) and the
 * optional boot-time check in index.ts (PREFLIGHT_ON_BOOT=1).
 *
 * Verifies OpenProject + FalkorDB (required) and Graphiti MCP (optional),
 * printing a ✅/❌/⚠️ report. Does NOT open/close connections beyond what each
 * check needs — callers own lifecycle (the CLI closes; the server keeps them).
 */
import { config } from './config.js';
import { getOpenProjectClient } from './openproject/client.js';
import { getGraph } from './graph/falkor.js';
import { memoryStatus } from './memory/index.js';

export type Check = { name: string; ok: boolean; detail: string; required: boolean };

async function checkOpenProject(): Promise<Check> {
  try {
    const conn = await getOpenProjectClient().testConnection();
    if (!conn.connected) {
      return { name: 'OpenProject', ok: false, required: true, detail: conn.error ?? 'not connected' };
    }
    return {
      name: 'OpenProject',
      ok: true,
      required: true,
      detail: `${conn.instanceName ?? 'instance'} (core ${conn.version ?? '?'}) @ ${config.openproject.baseUrl}`,
    };
  } catch (err: any) {
    return { name: 'OpenProject', ok: false, required: true, detail: err.message };
  }
}

async function checkFalkor(): Promise<Check> {
  try {
    const rows = await getGraph().query<{ c: number }>('MATCH (n) RETURN count(n) AS c');
    const count = rows[0]?.c ?? 0;
    return {
      name: 'FalkorDB',
      ok: true,
      required: true,
      detail: `${config.falkor.host}:${config.falkor.port} graph "${config.falkor.graph}" (${count} nodes)`,
    };
  } catch (err: any) {
    return { name: 'FalkorDB', ok: false, required: true, detail: err.message };
  }
}

async function checkMemory(): Promise<Check> {
  const s = await memoryStatus();
  return {
    name: `Memory (${s.provider})`,
    ok: s.enabled ? s.ok : true, // disabled is a valid, non-failing state
    required: false,
    detail: s.detail,
  };
}

/**
 * Run all checks, print the report, and return whether a REQUIRED check failed.
 * `prefix` lets the boot path tag lines (e.g. "[preflight] ").
 */
export async function runPreflight(prefix = ''): Promise<{ checks: Check[]; failedRequired: boolean }> {
  const checks = await collectChecks();

  let failedRequired = false;
  for (const c of checks) {
    const mark = c.ok ? '✅' : c.required ? '❌' : '⚠️ ';
    const tag = c.required ? '' : ' (optional)';
    console.log(`${prefix}${mark} ${c.name}${tag}: ${c.detail}`);
    if (!c.ok && c.required) failedRequired = true;
  }
  return { checks, failedRequired };
}

/** Run the checks silently and return them (for the console status endpoint). */
export async function collectChecks(): Promise<Check[]> {
  return [await checkOpenProject(), await checkFalkor(), await checkMemory()];
}
