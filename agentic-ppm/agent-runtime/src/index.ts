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

    // Provision the roster as STATEFUL Letta agents (background, best-effort) so
    // proactive reflection routes through agents that remember. No-op if Letta
    // isn't configured (reflection then falls back to a direct Claude call).
    if (config.letta.configured) {
      void import('./letta/client.js')
        .then(({ provisionRosterAgents }) =>
          provisionRosterAgents((m) => console.log(`[letta] ${m}`)),
        )
        .then((ids) => console.log(`[letta] provisioned ${ids?.length ?? 0} stateful roster agent(s)`))
        .catch((err) => console.warn(`[letta] provisioning failed (non-fatal): ${err.message}`));
    }

    // OPT-IN proactive autonomy scan. OFF by default (proactiveScanMinutes=0) —
    // this is NOT a cron/orchestrator. When the user opts in, it reflects over
    // recently-active entities only (stimulus-driven), never the whole portfolio.
    if (config.agents.proactive && config.agents.proactiveScanMinutes > 0) {
      const ms = config.agents.proactiveScanMinutes * 60_000;
      console.log(`[autonomy] opt-in proactive reflection every ${config.agents.proactiveScanMinutes} min`);
      setInterval(() => {
        void import('./agents/autonomy/proactive.js')
          .then(({ proactiveReflect }) => proactiveReflect())
          .catch((err) => console.warn(`[autonomy] proactive scan failed: ${err.message}`));
      }, ms).unref();
    }

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
