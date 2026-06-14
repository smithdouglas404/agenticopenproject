/**
 * ML-suggested rule thresholds from the learning loop (deterministic statistics).
 *
 * NEW BUILD ("Later" feature). The learning loop (outcomes.ts) records
 * predictions and resolves them against real outcomes; closed items that slipped
 * and human-confirmed alerts are the "BAD" cohort. Given an ontology class and a
 * metric, this pulls the historical metric value of the entities behind those BAD
 * outcomes and computes a SEPARATING threshold — a number a PM can drop straight
 * into a rule. No heavy ML: it's a percentile / cohort-mean split, fully
 * explainable ("Epics below 47% progress slipped in 8/10 closed cases").
 *
 * Degrades gracefully everywhere: empty graph, thin history (<5 samples), or an
 * unresolvable metric all return suggested:null with a rationale — never a throw.
 */
import { resolveOntologyNodes } from '../rules/evaluator.js';
import { resolveMetric } from '../rules/loader.js';
import { getGraph } from '../graph/falkor.js';

/** Operators a suggestion can recommend (subset of RuleOperator that fits a cutoff). */
export type SuggestOperator = 'lt' | 'gt' | 'lte' | 'gte' | 'crossed_below' | 'crossed_above';

export interface ThresholdSuggestion {
  metric: string;
  ontologyClass: string;
  /** The suggested cutoff, or null when there isn't enough history. */
  suggested: number | null;
  operator: SuggestOperator;
  /** Plain-English explanation citing the statistic used. */
  rationale: string;
  /** How many bad-outcome samples carried a usable metric value. */
  sampleSize: number;
  /** 0–1 — share of the bad cohort that lands on the breach side of the cutoff. */
  confidence: number;
}

const MIN_SAMPLES = 5;

/** A resolved prediction joined to the node it concerned + that node's outcome. */
interface BadOutcomeRow {
  nodeId: string;
  outcome: string;
  correctness: string;
}

/**
 * The "BAD" cohort: resolved predictions whose outcome means the predicted risk
 * materialized — a human confirmed it (correctness 'correct' via HITL) or the
 * graph-state resolution found a slip ('still-overdue', or 'closed' with
 * correctness 'correct'). Each row carries the nodeId so we can read its metric.
 */
async function badOutcomeNodeIds(): Promise<BadOutcomeRow[]> {
  try {
    return await getGraph().query<BadOutcomeRow>(
      `MATCH (p:Prediction { status: 'resolved' })
       WHERE p.correctness = 'correct' OR p.outcome IN ['still-overdue', 'human-confirmed']
       RETURN p.nodeId AS nodeId, p.outcome AS outcome, p.correctness AS correctness`,
    );
  } catch {
    return [];
  }
}

/** Lower (worse) cutoff metrics — being BELOW the threshold is the risk. */
const LOWER_IS_WORSE = new Set(['percentageDone', 'progress', 'avgProgress']);

/** Median of a numeric sample (sorted copy; even-length averages the middle two). */
function median(values: number[]): number {
  const s = [...values].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 === 0 ? (s[mid - 1] + s[mid]) / 2 : s[mid];
}

/** Mean of a numeric sample. */
function mean(values: number[]): number {
  return values.reduce((a, b) => a + b, 0) / values.length;
}

/** Round to one decimal so the suggestion reads cleanly. */
function round1(n: number): number {
  return Math.round(n * 10) / 10;
}

/**
 * Suggest a rule threshold for (ontologyClass, metric) from the bad-outcome
 * cohort. Method:
 *   1. Collect the metric value of every node behind a BAD outcome.
 *   2. If <5 usable samples, return null ("insufficient history").
 *   3. For a lower-is-worse metric (e.g. progress), the cutoff is the cohort
 *      MEDIAN and the operator is `lt` (below it = breach); for a higher-is-worse
 *      metric (e.g. overdue count) it's the median with `gt`.
 *   4. Confidence = share of the bad cohort that falls on the breach side of the
 *      cutoff (by construction ~0.5 at the median; a tight cohort pushes higher).
 */
export async function suggestThreshold(opts: {
  ontologyClass: string;
  metric: string;
}): Promise<ThresholdSuggestion> {
  const { ontologyClass, metric } = opts;
  const lowerIsWorse = LOWER_IS_WORSE.has(metric);
  const operator: SuggestOperator = lowerIsWorse ? 'lt' : 'gt';

  const base: ThresholdSuggestion = {
    metric,
    ontologyClass,
    suggested: null,
    operator,
    rationale: 'insufficient history',
    sampleSize: 0,
    confidence: 0,
  };

  const bad = await badOutcomeNodeIds();
  if (bad.length === 0) {
    return { ...base, rationale: 'no resolved bad-outcome predictions yet' };
  }

  // Only consider nodes of the requested class (so a progress cutoff for Epics
  // isn't polluted by Task outcomes). resolveOntologyNodes filters to the class.
  const badIds = [...new Set(bad.map((b) => b.nodeId).filter((id) => typeof id === 'string' && id.length > 0))];
  let nodes: Awaited<ReturnType<typeof resolveOntologyNodes>> = [];
  try {
    nodes = await resolveOntologyNodes(ontologyClass, badIds);
  } catch {
    nodes = [];
  }
  if (nodes.length === 0) {
    return { ...base, rationale: `no ${ontologyClass} entities found behind bad outcomes` };
  }

  // Read the metric value for each bad node (reusing the rules metric resolver,
  // so direct props and computed metrics both work). Keep only numeric values.
  const values: number[] = [];
  for (const node of nodes) {
    const v = await resolveMetric(metric, node).catch(() => undefined);
    if (typeof v === 'number' && !Number.isNaN(v)) values.push(v);
  }

  if (values.length < MIN_SAMPLES) {
    return {
      ...base,
      sampleSize: values.length,
      rationale: `insufficient history (${values.length} usable sample${values.length === 1 ? '' : 's'}, need ${MIN_SAMPLES})`,
    };
  }

  const cutoff = round1(median(values));
  const onBreachSide = values.filter((v) => (lowerIsWorse ? v < cutoff : v > cutoff)).length;
  // Median splits ~50/50; report the share at-or-worse than the cutoff so the
  // confidence reflects how concentrated the bad cohort is on the breach side.
  const atOrWorse = values.filter((v) => (lowerIsWorse ? v <= cutoff : v >= cutoff)).length;
  const confidence = Math.round((atOrWorse / values.length) * 100) / 100;

  const cohortMean = round1(mean(values));
  const direction = lowerIsWorse ? 'below' : 'above';
  const rationale =
    `${ontologyClass} ${direction} ${cutoff} ${metric} in ${atOrWorse}/${values.length} bad-outcome cases ` +
    `(cohort median ${cutoff}, mean ${cohortMean}); ${onBreachSide} strictly past the cutoff.`;

  return {
    metric,
    ontologyClass,
    suggested: cutoff,
    operator,
    rationale,
    sampleSize: values.length,
    confidence,
  };
}
