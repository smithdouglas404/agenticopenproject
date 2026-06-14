/**
 * Backfill CLI — seed the graph from existing OpenProject data.
 *
 * Run this ONCE before going live (and any time you want to re-sync from
 * scratch) so the agent reasons over a populated world-model on day one,
 * rather than waiting for webhooks to trickle in changes.
 *
 *   npm run sync:backfill
 *
 * Idempotent: every node/edge is an upsert, so re-running is safe. Work packages
 * whose sync_source is our own agent are skipped (no feedback loop). Memory
 * episodes are recorded too (FalkorDB-native by default).
 */
import { assertRuntimeConfig } from '../config.js';
import { getOpenProjectClient } from '../openproject/client.js';
import { getProjector } from '../projector/projector.js';
import { getGraph } from '../graph/falkor.js';
import { closeMemory } from '../memory/index.js';

async function main(): Promise<void> {
  assertRuntimeConfig();

  const conn = await getOpenProjectClient().testConnection();
  if (!conn.connected) {
    console.error(`OpenProject not reachable: ${conn.error}`);
    process.exit(1);
  }
  console.log(`Connected to OpenProject ${conn.instanceName ?? ''} (core ${conn.version ?? '?'}).`);
  console.log('Backfilling graph — this may take a while on large instances...\n');

  const started = Date.now();
  const result = await getProjector().syncAll({
    onProgress: (msg) => console.log(`  ${msg}`),
  });

  const secs = ((Date.now() - started) / 1000).toFixed(1);
  console.log(
    `\nDone in ${secs}s: ${result.projects} projects, ${result.workPackages} work packages` +
      ` (${result.skipped} skipped as agent-authored), ${result.relations} relations,` +
      ` ${result.releases} releases, ${result.timeEntries} time entries aggregated.`,
  );
}

main()
  .catch((err) => {
    console.error(err);
    process.exitCode = 1;
  })
  .finally(async () => {
    // Release the FalkorDB socket and the memory provider so the process exits.
    await Promise.allSettled([getGraph().close(), closeMemory()]);
  });
