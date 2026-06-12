/**
 * ZEN decision-core smoke test.
 *
 * WHAT: Builds a tiny in-memory kind:'decision' rule whose JDM is a single
 * decision table (percentageDone < 50 ⇒ breach, severity tiers), runs
 * evaluateDecisionRule against a couple of fake ResolvedNodes, and prints the
 * breaches — a runnable proof the GoRules ZEN core evaluates end to end.
 * WHY: Exercises the seam (decisionContext → ZenEngine → DecisionOutput →
 * RuleBreach) without needing FalkorDB or the OpenProject rules endpoint. Work-item
 * (non-project) nodes don't trigger computeProjectMetrics, but state.ts (cooldown)
 * does touch the graph, so we stub getGraph for a self-contained run.
 *
 *   npm run rules:zen-smoke
 */
import { evaluateDecisionRule, disposeZen } from '../rules/zenEvaluator.js';
import type { Rule } from '../rules/types.js';
import type { ResolvedNode } from '../rules/loader.js';
import { getGraph } from '../graph/falkor.js';

// --- Stub graph queries so state.ts (getState/setState) is a no-op offline. ---
// The FalkorGraph singleton connects lazily on first query; replacing its query
// method on the instance keeps the smoke self-contained (no DB, no rules endpoint).
(getGraph() as unknown as { query: () => Promise<unknown[]> }).query = async () => [];

/** JDM: input(percentageDone) -> decision table -> output(breach, severity). */
function progressJdm(): object {
  return {
    nodes: [
      { id: 'in', type: 'inputNode', name: 'Request', position: { x: 0, y: 0 } },
      {
        id: 'table',
        type: 'decisionTableNode',
        name: 'Progress check',
        position: { x: 200, y: 0 },
        content: {
          hitPolicy: 'first',
          inputs: [{ id: 'i1', field: 'percentageDone', name: 'Progress' }],
          outputs: [
            { id: 'o_breach', field: 'breach', name: 'Breach' },
            { id: 'o_sev', field: 'severity', name: 'Severity' },
            { id: 'o_msg', field: 'message', name: 'Message' },
          ],
          rules: [
            { _id: 'r1', i1: '< 25', o_breach: 'true', o_sev: '"critical"', o_msg: '"progress critically low"' },
            { _id: 'r2', i1: '< 50', o_breach: 'true', o_sev: '"warning"', o_msg: '"progress below target"' },
            { _id: 'r3', i1: '>= 50', o_breach: 'false' },
          ],
        },
      },
      { id: 'out', type: 'outputNode', name: 'Response', position: { x: 400, y: 0 } },
    ],
    edges: [
      { id: 'e1', sourceId: 'in', targetId: 'table' },
      { id: 'e2', sourceId: 'table', targetId: 'out' },
    ],
  };
}

const rule: Rule = {
  id: 9001,
  project_id: null,
  ontology_class: 'pm:Task',
  kind: 'decision',
  jdm: progressJdm(),
  metric: 'percentageDone',
  operator: 'lt',
  threshold: null,
  threshold2: null,
  severity: 'info',
  cooldown_minutes: 0,
  action_kind: 'alert',
  notify_openproject: false,
  notify_kyndral: false,
  enabled: true,
};

const nodes: ResolvedNode[] = [
  { id: 'op-wp-1', props: { name: 'Stalled task', progress: 15 } },
  { id: 'op-wp-2', props: { name: 'Half-done task', progress: 40 } },
  { id: 'op-wp-3', props: { name: 'On-track task', progress: 80 } },
];

async function main(): Promise<void> {
  console.log('Agentic PPM — ZEN decision-core smoke\n');
  const breaches = await evaluateDecisionRule(rule, nodes);
  console.log(`Evaluated ${nodes.length} node(s) -> ${breaches.length} breach(es):`);
  for (const b of breaches) {
    console.log(`  [${b.severity}] ${b.message}  (${b.nodeId}, ${b.metric}=${b.observedValue})`);
  }
  if (breaches.length === 2) {
    console.log('\nOK: expected 2 breaches (progress 15 critical, 40 warning); 80 did not fire.');
  } else {
    console.log('\nUNEXPECTED breach count — inspect output above.');
    process.exitCode = 1;
  }
}

main()
  .catch((err) => {
    console.error('zen-smoke failed:', err);
    process.exitCode = 1;
  })
  .finally(() => {
    disposeZen();
  });
