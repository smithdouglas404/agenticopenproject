/**
 * Preflight / doctor CLI.
 *
 * Checks every external dependency the agent needs and prints a pass/fail
 * report. Run it ON the Railway sidecar service (or locally) BEFORE the smoke
 * test — it confirms OpenProject, FalkorDB, and Graphiti are all reachable with
 * the configured env, so you find misconfiguration here instead of mid-event.
 *
 *   npm run preflight
 *
 * Exit code is non-zero if any REQUIRED check fails (Graphiti is optional).
 */
import { config } from '../config.js';
import { getOpenProjectClient } from '../openproject/client.js';
import { getGraph } from '../graph/falkor.js';
import { pingGraphiti, closeGraphiti } from '../graph/graphiti.js';

type Check = { name: string; ok: boolean; detail: string; required: boolean };

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

async function checkGraphiti(): Promise<Check> {
  const r = await pingGraphiti();
  if (!r.enabled) {
    return { name: 'Graphiti MCP', ok: true, required: false, detail: 'disabled (GRAPHITI_MCP_URL unset) — FalkorDB-only' };
  }
  if (!r.ok) {
    return { name: 'Graphiti MCP', ok: false, required: false, detail: r.error ?? 'unreachable' };
  }
  const hasAddMemory = r.tools?.includes(config.graphiti.addMemoryTool);
  return {
    name: 'Graphiti MCP',
    ok: true,
    required: false,
    detail:
      `${config.graphiti.mcpUrl} — ${r.tools?.length ?? 0} tools` +
      (hasAddMemory ? `, "${config.graphiti.addMemoryTool}" present` : `, ⚠ "${config.graphiti.addMemoryTool}" NOT found`),
  };
}

async function main(): Promise<void> {
  console.log('Agentic PPM — preflight\n');
  const checks = [await checkOpenProject(), await checkFalkor(), await checkGraphiti()];

  let failedRequired = false;
  for (const c of checks) {
    const mark = c.ok ? '✅' : c.required ? '❌' : '⚠️ ';
    const tag = c.required ? '' : ' (optional)';
    console.log(`${mark} ${c.name}${tag}: ${c.detail}`);
    if (!c.ok && c.required) failedRequired = true;
  }

  console.log(
    failedRequired
      ? '\nFAIL — fix the ❌ items above before the smoke test.'
      : '\nOK — required dependencies reachable.',
  );
  process.exitCode = failedRequired ? 1 : 0;
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    await Promise.allSettled([getGraph().close(), closeGraphiti()]);
  });
