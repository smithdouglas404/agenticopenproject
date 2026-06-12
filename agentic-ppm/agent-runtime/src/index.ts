/**
 * Agent-runtime sidecar entrypoint.
 *
 * Boots the OpenProject webhook receiver, which drives the Quick-slice pipeline:
 *   OpenProject webhook -> projector -> FalkorDB/Graphiti -> Insights & Risk agent -> inbox.
 */
import { config, assertRuntimeConfig } from './config.js';
import { buildApp } from './webhook/server.js';
import { getOpenProjectClient } from './openproject/client.js';
import { getProjector } from './projector/projector.js';
import { runPreflight } from './preflight.js';
import { startSweepLoop } from './agents/sweep.js';
import dns from 'node:dns';

// Railway's private network is IPv6-only. Node's fetch/undici otherwise prefers
// IPv4 and fails ("fetch failed") to reach *.railway.internal services such as
// the Graphiti MCP endpoint. Prefer IPv6 when running on Railway.
if (Object.keys(process.env).some((k) => k.startsWith('RAILWAY_'))) {
  dns.setDefaultResultOrder('ipv6first');
  console.log('[boot] DNS result order set to ipv6first (Railway private network is IPv6-only)');
}

async function main(): Promise<void> {
  assertRuntimeConfig();

  if (config.preflightOnBoot) {
    // Full dependency report (OpenProject + FalkorDB + Graphiti) at boot.
    console.log('[boot] PREFLIGHT_ON_BOOT=1 — checking dependencies:');
    const { failedRequired } = await runPreflight('[boot] ');
    if (failedRequired) console.warn('[boot] ⚠ required dependency unreachable — starting anyway');
  } else {
    // Best-effort connectivity check so misconfiguration surfaces at boot, not first event.
    const conn = await getOpenProjectClient().testConnection();
    if (conn.connected) {
      console.log(`[boot] OpenProject reachable: ${conn.instanceName ?? ''} (core ${conn.version ?? '?'})`);
    } else {
      console.warn(`[boot] OpenProject NOT reachable: ${conn.error}`);
    }
  }

  const app = buildApp();
  app.listen(config.port, () => {
    console.log(`[boot] agent-runtime listening on :${config.port}`);
    console.log(`[boot] webhook endpoint: POST http://<host>:${config.port}/webhooks/openproject`);
    console.log(`[boot] agent console: http://<host>:${config.port}/console`);
    startSweepLoop();

    if (config.runBackfillOnBoot) {
      // Seed the graph in the background so the server stays healthy meanwhile.
      // Idempotent (upserts), so it's safe to leave on — but unset it once seeded
      // to avoid re-scanning all of OpenProject on every deploy.
      console.log('[boot] RUN_BACKFILL_ON_BOOT=1 — seeding graph from OpenProject...');
      void getProjector()
        .syncAll({ onProgress: (msg) => console.log(`[backfill] ${msg}`) })
        .then((r) =>
          console.log(
            `[backfill] done: ${r.projects} projects, ${r.workPackages} work packages (${r.skipped} skipped), ` +
              `${r.relations} relations, ${r.releases} releases, ${r.timeEntries} time entries`,
          ),
        )
        .catch((err) => console.error(`[backfill] failed: ${err.message}`));
    }
  });
}

main().catch((err) => {
  console.error('[boot] fatal:', err);
  process.exit(1);
});
