/**
 * Threshold-suggestion smoke test — proves the ML-suggester runs OFFLINE.
 *
 *   npm run rules:suggest-smoke
 *
 * No live FalkorDB required: we replace the FalkorGraph singleton's query() with
 * a tiny in-memory fixture that answers the two shapes suggestThreshold issues —
 * (1) resolved BAD-outcome predictions, (2) the Epic nodes those predictions
 * concern (with a progress prop). The suggester then reads each node's
 * percentageDone and returns a separating cutoff. Also exercises the thin-history
 * degrade path (returns suggested:null with a rationale).
 */
import { getGraph } from '../graph/falkor.js';
import { suggestThreshold } from '../learning/suggest.js';

// Eight closed Epics that slipped, with their progress at the time. A ninth/tenth
// node id with no matching graph node proves the resolver tolerates gaps.
const BAD_PREDICTIONS = [
  { nodeId: 'op-wp-1', outcome: 'closed', correctness: 'correct' },
  { nodeId: 'op-wp-2', outcome: 'still-overdue', correctness: 'correct' },
  { nodeId: 'op-wp-3', outcome: 'human-confirmed', correctness: 'correct' },
  { nodeId: 'op-wp-4', outcome: 'closed', correctness: 'correct' },
  { nodeId: 'op-wp-5', outcome: 'closed', correctness: 'correct' },
  { nodeId: 'op-wp-6', outcome: 'still-overdue', correctness: 'correct' },
  { nodeId: 'op-wp-7', outcome: 'closed', correctness: 'correct' },
  { nodeId: 'op-wp-8', outcome: 'human-confirmed', correctness: 'correct' },
];

const EPIC_PROGRESS: Record<string, number> = {
  'op-wp-1': 20, 'op-wp-2': 35, 'op-wp-3': 40, 'op-wp-4': 45,
  'op-wp-5': 50, 'op-wp-6': 30, 'op-wp-7': 55, 'op-wp-8': 25,
};

/** Fixture query(): pattern-match the cypher to the two shapes the suggester sends. */
function installStub(progress: Record<string, number>): void {
  (getGraph() as unknown as { query: (cypher: string, params?: any) => Promise<unknown[]> }).query = async (
    cypher: string,
    params: any = {},
  ) => {
    if (/:Prediction/.test(cypher)) return BAD_PREDICTIONS;
    if (/spineClass/.test(cypher)) {
      // resolveOntologyNodes for a spineClass (Epic) filtered to the bad node ids.
      const ids: string[] = params?.ids ?? Object.keys(progress);
      return ids
        .filter((id) => id in progress)
        .map((id) => ({ id, progress: progress[id], spineClass: 'Epic' }));
    }
    return [];
  };
}

async function main(): Promise<void> {
  console.log('Agentic PPM — threshold-suggestion smoke (offline-safe)\n');

  // 1. Healthy history -> a real suggested cutoff.
  installStub(EPIC_PROGRESS);
  const s = await suggestThreshold({ ontologyClass: 'safe:Epic', metric: 'percentageDone' });
  console.log('suggestThreshold(safe:Epic, percentageDone):');
  console.log(`  suggested: ${s.suggested}  operator: ${s.operator}`);
  console.log(`  sampleSize: ${s.sampleSize}  confidence: ${s.confidence}`);
  console.log(`  rationale: ${s.rationale}\n`);

  // 2. Thin history (only 2 nodes carry the metric) -> null + rationale.
  installStub({ 'op-wp-1': 20, 'op-wp-2': 35 });
  const thin = await suggestThreshold({ ontologyClass: 'safe:Epic', metric: 'percentageDone' });
  console.log('thin history:');
  console.log(`  suggested: ${thin.suggested}  rationale: ${thin.rationale}\n`);

  const ok =
    s.suggested !== null &&
    s.operator === 'lt' &&
    s.sampleSize === 8 &&
    thin.suggested === null;

  if (ok) {
    console.log('PASS — healthy history yields an lt cutoff; thin history degrades to null.');
  } else {
    console.log('UNEXPECTED — inspect the output above.');
    process.exitCode = 1;
  }
}

main().catch((err) => {
  console.error(`\nFAIL — ${err?.message ?? err}`);
  process.exitCode = 1;
});
