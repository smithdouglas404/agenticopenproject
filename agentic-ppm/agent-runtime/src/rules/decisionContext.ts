/**
 * Decision-context builder — the INPUT SCHEMA a kind:'decision' JDM reads.
 *
 * WHAT: Assembles a flat, JSON-serializable object describing ONE resolved graph
 * node, which the ZEN engine evaluates a rule's JDM graph against. This is the
 * contract JDM authors target with their input expressions / unary tests.
 * WHY: GoRules JDM graphs reference fields by name (e.g. `percentageDone < 50`,
 * `overdue == true`). Centralizing the field set here keeps authoring stable and
 * keeps the seam pure: it never throws (a missing metric simply omits its field)
 * and never mutates the graph.
 *
 * INPUT SCHEMA (fields available to a JDM, all optional unless noted) ----------
 *   Identity / meta (always present):
 *     nodeId        string   graph node id (e.g. "op-wp-1234" / "op-project-7")
 *     ontologyClass string   the rule's ontology_class (e.g. "pm:Task")
 *     now           string   ISO timestamp of evaluation
 *
 *   Direct node properties (present when the graph supplied them):
 *     name, status, priority, assignee, source         (strings)
 *     endDate                                          (string, ISO date)
 *     progress, percentageDone (alias of progress)     (number)
 *     spentHours, estimatedHours, riskScore            (number)
 *     spineClass, projectId, workPackageId             (string/number)
 *
 *   Derived work-item fields (computed here, omitted when inputs are absent):
 *     budget_variance number   spentHours − estimatedHours
 *     overdue         boolean   endDate present AND endDate < today
 *     daysToDue       number    whole days from today to endDate (negative = past)
 *
 *   Computed project metrics (only for pm:Project nodes; reuse metrics.ts):
 *     openItems, overdue (count), pctOverdue, avgProgress,
 *     unassignedHigh, dueNext7Days                     (numbers)
 *   NOTE: for project nodes the boolean work-item `overdue` is NOT set; the
 *   numeric project `overdue` (count of overdue items) takes that key instead.
 */
import type { Rule } from './types.js';
import type { ResolvedNode } from './loader.js';
import { computeProjectMetrics } from '../grounding/metrics.js';

/** Read a numeric-ish value, tolerating string-encoded numbers from the graph. */
function num(value: unknown): number | undefined {
  if (typeof value === 'number' && !Number.isNaN(value)) return value;
  if (typeof value === 'string' && value.trim() !== '' && !Number.isNaN(Number(value))) return Number(value);
  return undefined;
}

/** Copy a prop onto ctx only when it is non-nullish (never feed undefined out). */
function put(ctx: Record<string, unknown>, key: string, value: unknown): void {
  if (value !== undefined && value !== null) ctx[key] = value;
}

const DAY_MS = 86_400_000;

/** Whole days from today (UTC date-only) to an ISO date; negative when past. */
function daysToDue(endDate: string): number | undefined {
  const due = Date.parse(endDate);
  if (Number.isNaN(due)) return undefined;
  const today = Date.parse(new Date().toISOString().slice(0, 10));
  return Math.round((due - today) / DAY_MS);
}

/** True when the ontology class resolves to a project (matches evaluator's map). */
function isProjectClass(ontologyClass: string): boolean {
  const tail = ontologyClass.includes(':') ? ontologyClass.split(':').pop()! : ontologyClass;
  return tail.toLowerCase() === 'project';
}

/**
 * Build the decision context for one node. Pure + deterministic; never throws.
 * Missing/unresolvable metrics are omitted rather than set to undefined.
 */
export async function buildDecisionContext(
  node: ResolvedNode,
  rule: Rule,
): Promise<Record<string, unknown>> {
  const ctx: Record<string, unknown> = {
    nodeId: node.id,
    ontologyClass: rule.ontology_class,
    now: new Date().toISOString(),
  };

  // --- direct node properties --------------------------------------------------
  const p = node.props;
  put(ctx, 'name', p.name);
  put(ctx, 'status', p.status == null ? undefined : String(p.status));
  put(ctx, 'priority', p.priority == null ? undefined : String(p.priority));
  put(ctx, 'assignee', p.assignee);
  put(ctx, 'source', p.source);
  put(ctx, 'endDate', p.endDate);
  put(ctx, 'spineClass', p.spineClass);
  put(ctx, 'projectId', p.projectId);
  put(ctx, 'workPackageId', p.workPackageId);

  const progress = num(p.progress);
  put(ctx, 'progress', progress);
  // Alias: JDM authors commonly key on the canonical metric name.
  put(ctx, 'percentageDone', progress);

  const spentHours = num(p.spentHours);
  const estimatedHours = num(p.estimatedHours);
  put(ctx, 'spentHours', spentHours);
  put(ctx, 'estimatedHours', estimatedHours);
  put(ctx, 'riskScore', num(p.riskScore ?? p.risk_score));

  if (isProjectClass(rule.ontology_class)) {
    // --- computed project metrics (reuse the deterministic channel) -----------
    try {
      const pm = await computeProjectMetrics(node.id);
      put(ctx, 'openItems', pm.openItems);
      put(ctx, 'overdue', pm.overdue);
      put(ctx, 'pctOverdue', pm.pctOverdue);
      put(ctx, 'avgProgress', pm.avgProgress);
      put(ctx, 'unassignedHigh', pm.unassignedHigh);
      put(ctx, 'dueNext7Days', pm.dueNext7Days);
    } catch {
      // Metric computation failed — omit the project fields, never throw.
    }
  } else {
    // --- derived work-item fields ---------------------------------------------
    if (spentHours != null && estimatedHours != null) {
      put(ctx, 'budget_variance', spentHours - estimatedHours);
    }
    if (typeof p.endDate === 'string' && p.endDate.trim() !== '') {
      const days = daysToDue(p.endDate);
      put(ctx, 'daysToDue', days);
      if (days != null) put(ctx, 'overdue', days < 0);
    }
  }

  return ctx;
}
