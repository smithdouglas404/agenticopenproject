/**
 * Webhook setup helper.
 *
 * STUB of DOSv2 `server/scripts/bootstrap-openproject.ts`. OpenProject webhook
 * creation is done through the admin UI (Administration > Webhooks) or the
 * webhooks API depending on version, so this script verifies connectivity and
 * prints exactly what to configure rather than guessing an endpoint that may not
 * exist on the target instance.
 *
 *   npm run seed:webhook
 */
import { config, assertRuntimeConfig } from '../config.js';
import { getOpenProjectClient } from '../openproject/client.js';

async function main(): Promise<void> {
  assertRuntimeConfig();
  const conn = await getOpenProjectClient().testConnection();
  if (!conn.connected) {
    console.error(`OpenProject not reachable: ${conn.error}`);
    process.exit(1);
  }

  console.log(`Connected to OpenProject ${conn.instanceName ?? ''} (core ${conn.version ?? '?'}).\n`);
  console.log('Configure a webhook under Administration > Webhooks with:');
  console.log(`  Payload URL : http://<this-host>:${config.port}/webhooks/openproject`);
  console.log(`  Secret      : (value of OPENPROJECT_WEBHOOK_SECRET)`);
  console.log('  Events      : work_package:created, work_package:updated, project:created, project:updated\n');
  console.log('Also ensure these exist in OpenProject (seeded by the modules/agentic_ppm Rails engine):');
  console.log(`  - Project with identifier "${config.openproject.alertsProject}" (the Insights inbox)`);
  console.log('  - WP custom fields: sync_source (text), alert_severity (list)');
  console.log('  - WP type "Agent Alert"');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
