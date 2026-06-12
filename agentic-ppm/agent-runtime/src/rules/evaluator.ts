/**
 * Rules evaluator — the runtime half of the OpenProject-authored rules engine.
 *
 * WHAT: Resolves each rule's ontology class to graph nodes, resolves the rule's
 * metric per node, applies the operator (respecting per-(rule,node) cooldown and
 * temporal state), and publishes breaches as findings into BOTH UIs:
 *   - the Kyndral findings API + OpenProject Agent Alert WP (via recordFinding)
 *   - the OpenProject module's native rules inbox (via alerts.json) when asked.
 * WHY: Rules are policy authored in OpenProject; this is the deterministic engine
 * that turns that policy into auditable breaches over the FalkorDB world-model.
 * It degrades gracefully: an empty graph or an unreachable endpoint yields zero
 * breaches, never a throw into the sweep.
 */
import { getGraph } from '../graph/falkor.js';
import { recordFinding, setFindingStatus } from '../store/findings.js';
import { writeFinding, type AlertSeverity } from '../inbox/inbox.js';
import { config } from '../config.js';
import type { Rule, RuleBreach, RuleSeverity } from './types.js';
import { loadRules, resolveMetric, resetMetricCaches, type ResolvedNode } from './loader.js';
import { getState, setState, withinCooldown } from './state.js';
import { evaluateDecisionRule } from './zenEvaluator.js';
import { postRuleAlert, type RuleAlertPayload } from './opModuleClient.js';

// ---------------------------------------------------------------------------
// Ontology class -> graph resolution
// ---------------------------------------------------------------------------

/** Map an ontology_class (e.g. "safe:Epic") to a graph label or a spineClass. */
interface ClassResolution {
  /** Match by exact node label (e.g. Project). */
  label?: string;
  /** Match by w.spineClass value (e.g. 'Epic'). */
  spineClass?: string;
}

const ONTOLOGY_MAP: Record<string, ClassResolution> = {
  'safe:Epic': { spineClass: 'Epic' },
  'safe:Feature': { spineClass: 'Feature' },
  'safe:Capability': { spineClass: 'Capability' },
  'pm:Task': { spineClass: 'Task' },
  'pm:Story': { spineClass: 'Story' },
  'pm:Issue': { spineClass: 'Issue' },
  'pm:Milestone': { spineClass: 'Milestone' },
  'pm:Risk': { spineClass: 'Risk' },
  'pm:Objective': { spineClass: 'Objective' },
  'pm:Project': { label: 'Project' },
};

/** Resolve an ontology_class to a {label?, spineClass?} match spec. */
function classResolution(ontologyClass: string): ClassResolution {
  const mapped = ONTOLOGY_MAP[ontologyClass];
  if (mapped) return mapped;
  // Default: strip any "prefix:" and treat the remainder as a spineClass.
  const tail = ontologyClass.includes(':') ? ontologyClass.split(':').pop()! : ontologyClass;
  if (tail.toLowerCase() === 'project') return { label: 'Project' };
  return { spineClass: tail };
}

/** Properties we surface on resolved nodes for metric resolution. */
const NODE_RETURN = `n.id AS id, n.name AS name, n.status AS status, n.priority AS priority,
  n.progress AS progress, n.assignee AS assignee, n.endDate AS endDate, n.source AS source,
  n.spentHours AS spentHours, n.estimatedHours AS estimatedHours, n.riskScore AS riskScore,
  n.projectId AS projectId, n.workPackageId AS workPackageId`;

/**
 * Resolve the graph nodes for an ontology class. When `nodeIds` is given, the
 * result is filtered to those ids (the event-driven targeted path).
 */
export async function resolveOntologyNodes(
  ontologyClass: string,
  nodeIds?: string[],
): Promise<ResolvedNode[]> {
  const spec = classResolution(ontologyClass);
  const graph = getGraph();
  const filterIds = nodeIds && nodeIds.length > 0;

  let rows: Array<Record<string, unknown> & { id: string }>;
  if (spec.label) {
    rows = await graph.query(
      `MATCH (n:${spec.label})
       ${filterIds ? 'WHERE n.id IN $ids' : ''}
       RETURN ${NODE_RETURN}
       LIMIT 500`,
      filterIds ? { ids: nodeIds } : {},
    );
  } else {
    rows = await graph.query(
      `MATCH (n)
       WHERE n.spineClass = $spineClass ${filterIds ? 'AND n.id IN $ids' : ''}
       RETURN ${NODE_RETURN}
       LIMIT 500`,
      filterIds ? { spineClass: spec.spineClass, ids: nodeIds } : { spineClass: spec.spineClass },
    );
  }

  return rows.map((r) => {
    const { id, ...rest } = r;
    return { id, props: rest };
  });
}

// ---------------------------------------------------------------------------
// Operator semantics
// ---------------------------------------------------------------------------

function isNum(v: unknown): v is number {
  return typeof v === 'number' && !Number.isNaN(v);
}

/**
 * Apply a rule's operator to a value, given the prior value from RuleState.
 * Returns true when the rule BREACHES. Operators that need a numeric value but
 * get a string (or a missing threshold) simply don't fire.
 */
function applyOperator(
  rule: Rule,
  value: number | string,
  previous: number | string | undefined,
): boolean {
  const t = rule.threshold;
  const t2 = rule.threshold2;

  switch (rule.operator) {
    case 'gt':
      return isNum(value) && t != null && value > t;
    case 'gte':
      return isNum(value) && t != null && value >= t;
    case 'lt':
      return isNum(value) && t != null && value < t;
    case 'lte':
      return isNum(value) && t != null && value <= t;
    case 'eq':
      return isNum(value) && t != null ? value === t : String(value) === String(t ?? '');
    case 'ne':
      return isNum(value) && t != null ? value !== t : String(value) !== String(t ?? '');
    case 'changed':
      return previous !== undefined && String(previous) !== String(value);
    case 'delta_gt':
      // |value − previous| > threshold (numeric only).
      return isNum(value) && isNum(previous) && t != null && Math.abs(value - previous) > t;
    case 'delta_lt':
      return isNum(value) && isNum(previous) && t != null && Math.abs(value - previous) < t;
    case 'outside_range':
      // value < threshold OR value > threshold2.
      return isNum(value) && ((t != null && value < t) || (t2 != null && value > t2));
    case 'crossed_above':
      // previous < threshold <= value (an upward crossing this pass).
      return isNum(value) && isNum(previous) && t != null && previous < t && value >= t;
    case 'crossed_below':
      // previous > threshold >= value (a downward crossing this pass).
      return isNum(value) && isNum(previous) && t != null && previous > t && value <= t;
    default:
      return false;
  }
}

/** Operator → human phrase for the breach message. */
const OPERATOR_PHRASE: Record<Rule['operator'], string> = {
  gt: '>',
  gte: '>=',
  lt: '<',
  lte: '<=',
  eq: '==',
  ne: '!=',
  changed: 'changed from',
  delta_gt: 'delta >',
  delta_lt: 'delta <',
  outside_range: 'outside range',
  crossed_above: 'crossed above',
  crossed_below: 'crossed below',
};

function buildMessage(rule: Rule, node: ResolvedNode, value: number | string, previous?: number | string): string {
  const name = (node.props.name as string | undefined) ?? node.id;
  const cls = rule.ontology_class.includes(':') ? rule.ontology_class.split(':').pop()! : rule.ontology_class;
  const phrase = OPERATOR_PHRASE[rule.operator];
  if (rule.operator === 'changed') {
    return `${cls} "${name}" ${rule.metric} ${phrase} ${previous ?? '(unknown)'} to ${value}`;
  }
  if (rule.operator === 'outside_range') {
    return `${cls} "${name}" ${rule.metric} ${value} outside range [${rule.threshold ?? '-∞'}, ${rule.threshold2 ?? '∞'}]`;
  }
  return `${cls} "${name}" ${rule.metric} ${value} ${phrase} threshold ${rule.threshold ?? ''}`.trim();
}

// ---------------------------------------------------------------------------
// Evaluation
// ---------------------------------------------------------------------------

/**
 * Evaluate one rule against a set of resolved nodes. Updates RuleState for every
 * node (so temporal operators have history next pass), suppresses firings within
 * cooldown, and returns the breaches.
 */
export async function evaluateRule(rule: Rule, nodes: ResolvedNode[]): Promise<RuleBreach[]> {
  // Decision rules route to the GoRules ZEN core; threshold rules fall through to
  // the operator logic below. evaluateRules/evaluateForChangedNodes call this, so
  // both sweep paths cover decision rules automatically.
  if (rule.kind === 'decision' && rule.jdm) {
    return evaluateDecisionRule(rule, nodes);
  }

  const breaches: RuleBreach[] = [];

  for (const node of nodes) {
    let value: number | string | undefined;
    try {
      value = await resolveMetric(rule.metric, node);
    } catch (err) {
      console.debug?.(`[rules] rule ${rule.id} metric '${rule.metric}' errored on ${node.id}: ${(err as Error).message}`);
      continue;
    }
    if (value === undefined) {
      // Unresolvable metric for this node — skip (debug, never crash).
      console.debug?.(`[rules] rule ${rule.id} metric '${rule.metric}' unresolvable for ${node.id}; skipping`);
      continue;
    }

    const state = await getState(rule.id, node.id);
    const previous = state?.lastValue;
    const fires = applyOperator(rule, value, previous);

    if (fires && !withinCooldown(state, rule.cooldown_minutes)) {
      breaches.push({
        rule,
        nodeId: node.id,
        ontologyClass: rule.ontology_class,
        metric: rule.metric,
        observedValue: value,
        previousValue: previous,
        threshold: rule.threshold ?? undefined,
        threshold2: rule.threshold2 ?? undefined,
        severity: rule.severity,
        message: buildMessage(rule, node, value, previous),
      });
      // Firing updates BOTH the value and the cooldown clock.
      await setState(rule.id, node.id, value, new Date().toISOString());
    } else {
      // Non-firing pass: remember the value (for delta/changed/crossed) but keep
      // the existing lastFiredAt so cooldown isn't reset.
      await setState(rule.id, node.id, value);
    }
  }

  return breaches;
}

/**
 * Load and evaluate all rules. When opts.nodeIds is given, only nodes with those
 * ids are considered (the event-driven targeted path); otherwise the whole class.
 */
export async function evaluateRules(opts?: { nodeIds?: string[] }): Promise<RuleBreach[]> {
  if (!config.rules.enabled) return [];
  resetMetricCaches();
  const rules = await loadRules();
  if (rules.length === 0) return [];

  const all: RuleBreach[] = [];
  for (const rule of rules) {
    try {
      const nodes = await resolveOntologyNodes(rule.ontology_class, opts?.nodeIds);
      if (nodes.length === 0) continue;
      const breaches = await evaluateRule(rule, nodes);
      all.push(...breaches);
    } catch (err) {
      console.warn(`[rules] rule ${rule.id} evaluation failed: ${(err as Error).message}`);
    }
  }
  return all;
}

/** Event-driven entry point: evaluate only the rules touching the changed nodes. */
export async function evaluateForChangedNodes(nodeIds: string[]): Promise<RuleBreach[]> {
  if (!config.rules.enabled || !config.rules.evaluateOnEvent || nodeIds.length === 0) return [];
  return evaluateRules({ nodeIds });
}

// ---------------------------------------------------------------------------
// Publishing
// ---------------------------------------------------------------------------

const RULE_SEVERITY_TO_FINDING: Record<RuleSeverity, 'low' | 'medium' | 'high'> = {
  info: 'low',
  warning: 'medium',
  critical: 'high',
};

const FINDING_SEVERITY_TO_ALERT: Record<'low' | 'medium' | 'high', AlertSeverity> = {
  low: 'notification',
  medium: 'warning',
  high: 'alarm',
};

/** Derive an OpenProject WP id from a graph node id like "op-wp-1234". */
function workPackageId(nodeId: string): number | undefined {
  const m = nodeId.match(/op-wp-(\d+)/);
  return m ? Number(m[1]) : undefined;
}

/** Derive an OpenProject project id from a graph node id like "op-project-7". */
function projectId(nodeId: string): number | undefined {
  const m = nodeId.match(/op-project-(\d+)/);
  return m ? Number(m[1]) : undefined;
}

/**
 * Publish breaches into BOTH UIs:
 *   1. recordFinding({type:'RuleBreach', agentId:'rules', ...}) — routes to the
 *      Kyndral findings API and (when DETECTOR_PUBLISH) the OpenProject Agent
 *      Alert WP. Dedup is handled by recordFinding's (type, nodeId) keying.
 *   2. when rule.notify_openproject, POST alerts.json so the breach also lands in
 *      OpenProject's native rules inbox.
 * Returns the count of NEW findings (deduped).
 */
export async function publishBreaches(breaches: RuleBreach[]): Promise<number> {
  let newCount = 0;

  for (const b of breaches) {
    const severity = RULE_SEVERITY_TO_FINDING[b.severity];
    const wpId = workPackageId(b.nodeId);
    const title = `Rule #${b.rule.id} ${b.metric} breach`;

    const { finding, isNew } = await recordFinding({
      type: 'RuleBreach',
      agentId: 'rules',
      severity,
      title,
      body: b.message,
      nodeId: b.nodeId,
      workPackageId: wpId,
      evidence: [
        { entityId: b.nodeId, metric: b.metric, value: String(b.observedValue) },
      ],
    });

    if (isNew) {
      newCount++;
      // Mirror the sweep's publish path so RuleBreaches appear as Agent Alert WPs.
      if (config.detectors.publish) {
        try {
          const alertWpId = await writeFinding({
            title: `RuleBreach: ${b.message}`,
            body: `${b.message}\n\nAgent: rules · Rule #${b.rule.id} · Finding: ${finding.id}`,
            severity: FINDING_SEVERITY_TO_ALERT[severity],
            relatedWorkPackageId: wpId,
          });
          await setFindingStatus(finding.id, 'published', { alertWpId });
        } catch (err) {
          console.warn(`[rules] Agent Alert publish failed for ${finding.id}: ${(err as Error).message}`);
        }
      }
    }

    // Native OpenProject rules inbox — fire even on dedup so the module reflects
    // a standing breach, but only when the rule asks for it.
    if (b.rule.notify_openproject) {
      const payload: RuleAlertPayload = {
        agent: 'rules',
        ontology_subject: b.nodeId,
        title,
        body: b.message,
        severity: b.severity,
        confidence: 1,
        evidence: {
          rule_id: b.rule.id,
          metric: b.metric,
          observed_value: b.observedValue,
          threshold: b.rule.threshold,
          operator: b.rule.operator,
        },
        project_id: b.rule.project_id ?? projectId(b.nodeId),
        work_package_id: wpId,
      };
      await postRuleAlert(payload);
    }
  }

  return newCount;
}
