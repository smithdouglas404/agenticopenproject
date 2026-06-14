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

/**
 * Build the resolvable-metrics catalog for a source (default 'openproject').
 * Order: canonical ontology properties → direct resolver aliases → computed →
 * mapped custom fields. Deduped by key (first wins).
 */
export async function buildMetricsCatalog(source = 'openproject'): Promise<MetricCatalogEntry[]> {
  const out: MetricCatalogEntry[] = [];
  const seen = new Set<string>();
  const push = (e: MetricCatalogEntry) => {
    if (seen.has(e.key)) return;
    seen.add(e.key);
    out.push(e);
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
