/**
 * Provision the 9 roster agents in Letta (idempotent), powered by Claude.
 *
 *   npm run letta:provision
 *
 * Requires LETTA_API_KEY (Letta Cloud) or LETTA_BASE_URL (self-hosted server).
 * Set LETTA_MODEL to a Claude handle from your Letta workspace if the default
 * doesn't match. Safe to re-run — existing agents are detected by name.
 */
import { config } from '../config.js';
import { lettaConfigured, provisionRosterAgents } from '../letta/client.js';

async function main(): Promise<void> {
  if (!lettaConfigured()) {
    console.error('Letta not configured. Set LETTA_API_KEY (Letta Cloud) or LETTA_BASE_URL (self-hosted).');
    process.exit(1);
  }
  console.log(`Provisioning roster agents in Letta (${config.letta.baseUrl}), model ${config.letta.model}...\n`);
  const ids = await provisionRosterAgents((m) => console.log(`  ${m}`));
  console.log(`\nDone: ${Object.keys(ids).length} agents ready.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
