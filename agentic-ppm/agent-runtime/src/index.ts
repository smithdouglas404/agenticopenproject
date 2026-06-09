/**
 * Agent-runtime sidecar entrypoint.
 *
 * Boots the OpenProject webhook receiver, which drives the Quick-slice pipeline:
 *   OpenProject webhook -> projector -> FalkorDB/Graphiti -> Insights & Risk agent -> inbox.
 */
import { config, assertRuntimeConfig } from './config.js';
import { buildApp } from './webhook/server.js';
import { getOpenProjectClient } from './openproject/client.js';

async function main(): Promise<void> {
  assertRuntimeConfig();

  // Best-effort connectivity check so misconfiguration surfaces at boot, not first event.
  const conn = await getOpenProjectClient().testConnection();
  if (conn.connected) {
    console.log(`[boot] OpenProject reachable: ${conn.instanceName ?? ''} (core ${conn.version ?? '?'})`);
  } else {
    console.warn(`[boot] OpenProject NOT reachable: ${conn.error}`);
  }

  const app = buildApp();
  app.listen(config.port, () => {
    console.log(`[boot] agent-runtime listening on :${config.port}`);
    console.log(`[boot] webhook endpoint: POST http://<host>:${config.port}/webhooks/openproject`);
  });
}

main().catch((err) => {
  console.error('[boot] fatal:', err);
  process.exit(1);
});
