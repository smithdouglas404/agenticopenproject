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
 * Shares its check logic with the boot-time PREFLIGHT_ON_BOOT=1 path.
 */
import { runPreflight } from '../preflight.js';
import { getGraph } from '../graph/falkor.js';
import { closeMemory } from '../memory/index.js';

async function main(): Promise<void> {
  console.log('Agentic PPM — preflight\n');
  const { failedRequired } = await runPreflight();
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
    await Promise.allSettled([getGraph().close(), closeMemory()]);
  });
