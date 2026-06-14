/**
 * ML-suggested rule thresholds from the learning loop.
 *
 * The learning loop already turns HITL decisions into labels: an approved finding
 * is a TRUE positive (the breach was real), a rejected finding is a FALSE positive
 * (noise). Each finding carries `evidence` ([{entityId, metric, value}]) — the
 * observed metric value at breach time. So for a threshold rule on metric M we can
 * look at the labeled breach values for M and suggest a threshold that best
 * separates real breaches from noise:
 *
 *   operator gt/gte (breach when value ≥ threshold):
 *     false positives sit just ABOVE the threshold → RAISE it to the bottom of the
 *     confirmed cluster (min confirmed value) so the noise stops breaching.
 *   operator lt/lte (breach when value ≤ threshold):
 *     mirror — LOWER it to the top of the confirmed cluster (max confirmed value).
 *
 * This is deterministic + auditable (no opaque model): the suggestion always cites
 * its sample size and confirmed/rejected split. Advisory only — a human still edits
 * the rule in OpenProject (rules stay authored there). Degrades to [] when learning
 * is disabled or there isn't enough labeled history. Never throws.
 */
import { config } from '../config.js';
import { loadRules } from '../rules/loader.js';
import { listFindings, type StoredFinding } from '../store/findings.js';
import type { Rule } from '../rules/types.js';

export interface ThresholdSuggestion {
  ruleId: number;
  label: string;
  metric: string;
  operator: string;
  currentThreshold: number | null;
  suggestedThreshold: number | null;
  direction: 'raise' | 'lower' | 'keep';
  confidence: 'low' | 'medium' | 'high';
  sampleSize: number;
  confirmed: number;
  rejected: number;
  rationale: string;
}

const MIN_SAMPLE = 3;
const TUNABLE = new Set(['gt', 'gte', 'lt', 'lte']);

/** Parse a finding's evidence JSON into typed citations (never throws). */
function evidenceOf(f: StoredFinding): { metric: string; value: number }[] {
  if (!f.evidence) return [];
  try {
    const parsed: unknown = JSON.parse(f.evidence);
    if (!Array.isArray(parsed)) return [];
    return parsed
      .map((e: any) => ({ metric: String(e?.metric ?? ''), value: Number(e?.value) }))
      .filter((e) => e.metric && Number.isFinite(e.value));
  } catch {
    return [];
  }
}

function round(n: number): number {
  // Keep one decimal for sub-unit metrics, whole numbers otherwise.
  return Math.abs(n) < 10 ? Math.round(n * 10) / 10 : Math.round(n);
}

function labelFor(rule: Rule): string {
  const cls = rule.ontology_class ? `${rule.ontology_class} · ` : '';
  return `${cls}${rule.metric} ${rule.operator} ${rule.threshold ?? ''}`.trim();
}

function suggestForRule(
  rule: Rule,
  confirmed: number[],
  rejected: number[],
): ThresholdSuggestion {
  const sampleSize = confirmed.length + rejected.length;
  const base: ThresholdSuggestion = {
    ruleId: rule.id,
    label: labelFor(rule),
    metric: rule.metric,
    operator: rule.operator,
    currentThreshold: rule.threshold,
    suggestedThreshold: rule.threshold,
    direction: 'keep',
    confidence: sampleSize >= 10 ? 'high' : sampleSize >= 5 ? 'medium' : 'low',
    sampleSize,
    confirmed: confirmed.length,
    rejected: rejected.length,
    rationale: '',
  };

  if (!TUNABLE.has(rule.operator)) {
    return { ...base, rationale: `operator "${rule.operator}" is not a single-threshold comparison; not auto-tunable` };
  }
  if (sampleSize < MIN_SAMPLE) {
    return { ...base, rationale: `insufficient labeled history (${sampleSize} decided finding(s); need ${MIN_SAMPLE})` };
  }
  if (rejected.length === 0) {
    return { ...base, rationale: `${confirmed.length} confirmed, 0 rejected — threshold looks well-calibrated` };
  }

  const isUpper = rule.operator === 'gt' || rule.operator === 'gte'; // breach when value high
  let suggested: number;
  if (isUpper) {
    // Raise to the bottom of the confirmed cluster so the rejected (noise) stop breaching.
    suggested = confirmed.length ? Math.min(...confirmed) : Math.max(...rejected);
  } else {
    // Lower to the top of the confirmed cluster.
    suggested = confirmed.length ? Math.max(...confirmed) : Math.min(...rejected);
  }
  suggested = round(suggested);

  const cur = rule.threshold;
  let direction: 'raise' | 'lower' | 'keep' = 'keep';
  if (cur == null || suggested === cur) direction = 'keep';
  else if (suggested > cur) direction = 'raise';
  else direction = 'lower';

  const falsePositiveRate = Math.round((rejected.length / sampleSize) * 100);
  const rationale =
    direction === 'keep'
      ? `${falsePositiveRate}% of decided breaches were rejected, but the suggested value matches the current threshold`
      : `${falsePositiveRate}% of decided breaches (${rejected.length}/${sampleSize}) were rejected as noise; ` +
        `${direction} the threshold to ${suggested} to fire on the confirmed band instead`;

  return { ...base, suggestedThreshold: suggested, direction, rationale };
}

/**
 * Suggest thresholds for the active threshold rules, learned from decided
 * findings. Decision rules (kind:'decision') and non-comparison operators are
 * reported as not-tunable rather than dropped, so the UI can show every rule.
 */
export async function suggestThresholds(): Promise<ThresholdSuggestion[]> {
  if (!config.learning.enabled) return [];
  try {
    const [rules, approved, rejected] = await Promise.all([
      loadRules().catch(() => [] as Rule[]),
      listFindings({ status: 'approved', limit: 500 }).catch(() => [] as StoredFinding[]),
      listFindings({ status: 'rejected', limit: 500 }).catch(() => [] as StoredFinding[]),
    ]);

    // Index labeled observed values by metric.
    const confirmedByMetric = new Map<string, number[]>();
    const rejectedByMetric = new Map<string, number[]>();
    const index = (findings: StoredFinding[], target: Map<string, number[]>) => {
      for (const f of findings) {
        for (const ev of evidenceOf(f)) {
          (target.get(ev.metric) ?? target.set(ev.metric, []).get(ev.metric)!).push(ev.value);
        }
      }
    };
    index(approved, confirmedByMetric);
    index(rejected, rejectedByMetric);

    return rules
      .filter((r) => (r.kind ?? 'threshold') === 'threshold')
      .map((r) =>
        suggestForRule(r, confirmedByMetric.get(r.metric) ?? [], rejectedByMetric.get(r.metric) ?? []),
      );
  } catch (err) {
    console.warn(`[thresholds] suggestion failed: ${(err as Error).message}`);
    return [];
  }
}
