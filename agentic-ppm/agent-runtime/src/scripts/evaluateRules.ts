/**
 * Rules evaluation CLI.
 *
 * WHAT: Loads the OpenProject-authored rules, evaluates them against the current
 * FalkorDB graph, publishes any breaches into both UIs, and prints a summary.
 * WHY: Manual testing / on-demand evaluation outside the periodic sweep —
 * confirms the rules endpoint is reachable and the metric/operator wiring fires.
 *
 *   npm run rules:eval
 */
import { loadRules } from '../rules/loader.js';
import { evaluateRules, publishBreaches } from '../rules/evaluator.js';
import { getGraph } from '../graph/falkor.js';
import { config } from '../config.js';

async function main(): Promise<void> {
  console.log('Agentic PPM — rules evaluation\n');
  console.log(`source=${config.rules.source} enabled=${config.rules.enabled}\n`);

  const rules = await loadRules();
  console.log(`Loaded ${rules.length} enabled rule(s).`);
  for (const r of rules) {
    console.log(
      `  #${r.id} ${r.ontology_class}.${r.metric} ${r.operator} ${r.threshold ?? ''}` +
        `${r.threshold2 != null ? `..${r.threshold2}` : ''} [${r.severity}] cooldown=${r.cooldown_minutes}m`,
    );
  }

  const breaches = await evaluateRules();
  console.log(`\nEvaluated -> ${breaches.length} breach(es):`);
  for (const b of breaches) {
    console.log(`  [${b.severity}] ${b.message}  (${b.nodeId})`);
  }

  const newCount = await publishBreaches(breaches);
  console.log(`\nPublished ${newCount} new finding(s) (deduped against open findings).`);
}

main()
  .catch((err) => {
    console.error('rules:eval failed:', err);
    process.exitCode = 1;
  })
  .finally(() => {
    void getGraph().close();
  });
