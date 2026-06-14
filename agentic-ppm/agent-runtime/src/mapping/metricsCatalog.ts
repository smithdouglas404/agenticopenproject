/**
 * Metrics catalog — the single list of every metric/attribute that can be used
 * as a rule threshold target or bound to a dashboard widget.
 *
 * WHY: the Kyndral RulesPanel metric picker and the widget palette both need to
 * know "what can I threshold / chart?". That answer is spread across three
 * places in the runtime: the canonical ontology properties (the mappable spine),
 * the rule METRIC_RESOLVERS (direct props + project-scoped COMPUTED metrics in
 * src/rules/loader.ts), and the mapped custom fields from the active MappingSet.
 * This assembles them into one deduped, kind-tagged catalog.
 *
 * The 'agent' kind (per-agent computed attributes from the Kyndral
 * agent_attributes table) is merged in by the Kyndral proxy
 * (/api/agent/metrics-catalog), which owns that table — the runtime doesn't.
 *
 * Each entry can also carry advisory facets — `methodology[]` (agile/safe/…) and
 * `agent` (the roster owner) — so a caller can narrow the catalog to a delivery
 * methodology, an industry, or a single agent's metrics. Filtering is OPTIONAL
 * and backward-compatible: with no filters the full catalog is returned exactly
 * as before.
 *
 * Resilient: never throws. If the mapping store is unreachable the custom-field
 * section is simply omitted.
 */
import { listOntologyProperties } from './ontologyProperties.js';
import { getMapping } from './store.js';
import type { AttributeType } from './types.js';

export type MetricKind = 'standard' | 'computed' | 'custom' | 'agent';

export interface MetricCatalogEntry {
  /** The metric key used in a rule's `metric` field or a widget binding. */
  key: string;
  label: string;
  kind: MetricKind;
  dataType: AttributeType | string;
  unit: string | null;
  /** Set only for kind:'agent' entries (added by the Kyndral proxy). */
  agentId?: string;
  /**
   * Delivery methodologies this metric is relevant to (e.g. ['agile','safe']).
   * Omitted = methodology-agnostic (applies to every methodology).
   */
  methodology?: string[];
  /**
   * Industries this metric is specific to. Omitted = industry-agnostic (applies
   * to every industry). Currently every built-in metric is agnostic; the facet
   * exists so mapped/extension metrics can scope themselves.
   */
  industry?: string[];
  /** Roster agent that owns/uses this metric (provenance), when determinable. */
  agent?: string;
}

/** Filters for {@link buildMetricsCatalog}. All optional; omit for full catalog. */
export interface MetricsCatalogFilters {
  /** Keep metrics relevant to this methodology (agnostic metrics always pass). */
  methodology?: string;
  /** Keep metrics relevant to this industry (agnostic metrics always pass). */
  industry?: string;
  /** Keep only metrics owned/used by this roster agent id. */
  agent?: string;
}

/**
 * Advisory facet tags per metric key. Keyed by the catalog `key` (the ontology
 * property id, resolver alias, or computed-metric key). A key absent here gets
 * no facets (methodology-/industry-agnostic, no specific agent). These describe
 * *relevance*, not access control — they only drive optional narrowing.
 */
const METRIC_FACETS: Record<string, { methodology?: string[]; agent?: string }> = {
  // ── computed metrics ──
  schedule_variance_days: { methodology: ['agile', 'safe', 'waterfall'], agent: 'strategic-pmo' },
  overduePct: { methodology: ['agile', 'safe', 'waterfall', 'kanban'], agent: 'strategic-pmo' },
  avgProgress: { methodology: ['agile', 'safe', 'waterfall', 'kanban'], agent: 'strategic-pmo' },
  openItems: { methodology: ['agile', 'safe', 'kanban'], agent: 'strategic-pmo' },
  unassignedHigh: { methodology: ['agile', 'safe'], agent: 'planning' },
  budget_variance: { agent: 'finops' }, // methodology-agnostic
  // ── direct resolver aliases ──
  percentageDone: { methodology: ['agile', 'safe', 'waterfall', 'kanban'], agent: 'strategic-pmo' },
  status: {}, // universal
  priority: {}, // universal
  spentHours: { agent: 'finops' },
  estimatedHours: { agent: 'finops' },
  risk_score: { agent: 'risk' },
  // ── canonical ontology properties (namespaced ids) ──
  'pm:percentComplete': { methodology: ['agile', 'safe', 'waterfall', 'kanban'], agent: 'strategic-pmo' },
  'pm:storyPoints': { methodology: ['agile', 'safe'], agent: 'planning' },
  'pm:effortHours': { agent: 'planning' },
  'pm:actualHours': { agent: 'finops' },
  'pm:riskScore': { agent: 'risk' },
  'pm:budgetVariance': { agent: 'finops' },
  'pm:release': { methodology: ['agile', 'safe'], agent: 'strategic-pmo' },
  'k360:objective': { agent: 'okr' },
  'k360:keyResult': { agent: 'okr' },
};

/** Apply the known facet tags to an entry (no-op when the key isn't tagged). */
function withFacets(entry: MetricCatalogEntry): MetricCatalogEntry {
  const f = METRIC_FACETS[entry.key];
  if (!f) return entry;
  return {
    ...entry,
    ...(f.methodology ? { methodology: f.methodology } : {}),
    ...(f.agent ? { agent: f.agent } : {}),
  };
}

/** Project-scoped COMPUTED metrics — mirror the computed METRIC_RESOLVERS. */
const COMPUTED: MetricCatalogEntry[] = [
  { key: 'schedule_variance_days', label: 'Schedule Variance (overdue items)', kind: 'computed', dataType: 'number', unit: 'days' },
  { key: 'overduePct', label: 'Overdue %', kind: 'computed', dataType: 'percentage', unit: '%' },
  { key: 'avgProgress', label: 'Average Progress', kind: 'computed', dataType: 'percentage', unit: '%' },
  { key: 'openItems', label: 'Open Items', kind: 'computed', dataType: 'number', unit: 'count' },
  { key: 'unassignedHigh', label: 'Unassigned High-Priority', kind: 'computed', dataType: 'number', unit: 'count' },
  { key: 'budget_variance', label: 'Budget Variance (spent − estimate)', kind: 'computed', dataType: 'number', unit: 'hours' },
];

/** Direct work-item/project props usable as rule metrics (direct METRIC_RESOLVERS). */
const STANDARD_RESOLVERS: MetricCatalogEntry[] = [
  { key: 'percentageDone', label: 'Percent Done', kind: 'standard', dataType: 'percentage', unit: '%' },
  { key: 'status', label: 'Status', kind: 'standard', dataType: 'enum', unit: null },
  { key: 'priority', label: 'Priority', kind: 'standard', dataType: 'enum', unit: null },
  { key: 'spentHours', label: 'Spent Hours', kind: 'standard', dataType: 'duration', unit: 'hours' },
  { key: 'estimatedHours', label: 'Estimated Hours', kind: 'standard', dataType: 'duration', unit: 'hours' },
  { key: 'risk_score', label: 'Risk Score', kind: 'standard', dataType: 'number', unit: null },
];

function unitForType(t: string): string | null {
  switch (t) {
    case 'percentage': return '%';
    case 'duration': return 'hours';
    case 'currency': return '$';
    default: return null;
  }
}

/** Does an entry pass an optional facet filter? Agnostic (untagged) always passes. */
function passesFilters(entry: MetricCatalogEntry, filters: MetricsCatalogFilters): boolean {
  if (filters.agent && entry.agent !== filters.agent) return false;
  if (filters.methodology && entry.methodology && !entry.methodology.includes(filters.methodology)) {
    return false; // tagged with methodologies, none of which match
  }
  if (filters.industry && entry.industry && !entry.industry.includes(filters.industry)) {
    return false; // tagged with industries, none of which match
  }
  return true;
}

/**
 * Build the resolvable-metrics catalog for a source (default 'openproject').
 * Order: canonical ontology properties → direct resolver aliases → computed →
 * mapped custom fields. Deduped by key (first wins).
 *
 * `filters` optionally narrows by methodology, industry, and/or agent. Metrics
 * with no tag for a given facet are treated as agnostic and always pass that
 * facet, so the filter only removes metrics that explicitly DON'T apply. With no
 * filters the result is identical to the unfiltered catalog (backward-compatible).
 */
export async function buildMetricsCatalog(
  source = 'openproject',
  filters: MetricsCatalogFilters = {},
): Promise<MetricCatalogEntry[]> {
  const out: MetricCatalogEntry[] = [];
  const seen = new Set<string>();
  const push = (e: MetricCatalogEntry) => {
    if (seen.has(e.key)) return;
    seen.add(e.key);
    const tagged = withFacets(e);
    if (!passesFilters(tagged, filters)) return;
    out.push(tagged);
  };

  // 1. Canonical ontology properties (the mappable spine).
  for (const p of listOntologyProperties()) {
    push({ key: p.id, label: p.label, kind: 'standard', dataType: p.type, unit: unitForType(p.type) });
  }

  // 2. Direct resolver aliases (rule-metric names the evaluator understands).
  STANDARD_RESOLVERS.forEach(push);

  // 3. Project-scoped computed metrics.
  COMPUTED.forEach(push);

  // 4. Mapped custom fields from the active MappingSet (kind:'custom').
  try {
    const set = await getMapping(source);
    for (const m of set.mappings ?? []) {
      if (!m.synced) continue;
      const isCustom = /customfield/i.test(m.sourceKey) || /^cf_/i.test(m.sourceKey);
      if (!isCustom) continue;
      const key = m.ontologyProperty || m.sourceKey;
      push({ key, label: m.sourceLabel || key, kind: 'custom', dataType: 'string', unit: null });
    }
  } catch {
    /* mapping store unreachable — omit custom fields, never fail the catalog */
  }

  return out;
}
