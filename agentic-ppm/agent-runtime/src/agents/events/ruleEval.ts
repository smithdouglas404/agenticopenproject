/**
 * Domain-rule evaluation — the deterministic core of one agent's reaction.
 *
 * WHAT: Resolves an entity's attribute values (reusing buildDecisionContext, the
 * SAME field set the JDM rules read), tests each enabled DomainRule of an agent's
 * DomainPack, and returns the rules that FIRED (all conditions held) plus the
 * observed values. applyFiredRules then turns those firings into deduped findings
 * and collects the a2a handoff targets.
 * WHY: Keeping evaluation deterministic + side-effect-free (evaluateDomainRules)
 * separate from recording (applyFiredRules) lets the cascade reason about what an
 * agent WOULD do before it commits, and keeps the whole thing testable offline.
 * It degrades gracefully: an attribute that can't be resolved skips that single
 * condition (never crashes), and a node that resolves to nothing fires nothing.
 */
import type { DomainRule, DomainRuleAction, Severity } from '../domains/types.js';
import { getDomainPack } from '../domains/index.js';
import { buildDecisionContext } from '../../rules/decisionContext.js';
import type { ResolvedNode } from '../../rules/loader.js';
import type { Rule } from '../../rules/types.js';
import { recordFinding } from '../../store/findings.js';
import { normalizeAttr } from './relevance.js';

/** A rule of one agent that fired on a node, with the values that made it fire. */
export interface FiredRule {
  rule: DomainRule;
  action: DomainRuleAction;
  observed: Record<string, unknown>;
  severity: Severity;
}

/** Synthesize the minimal Rule shape buildDecisionContext needs (ontology_class). */
function asContextRule(ontologyClass: string | undefined): Rule {
  return {
    id: 0,
    project_id: null,
    ontology_class: ontologyClass ?? '',
    metric: '',
    operator: 'eq',
    threshold: null,
    threshold2: null,
    severity: 'info',
    cooldown_minutes: 0,
    action_kind: 'alert',
    notify_openproject: false,
    notify_kyndral: false,
    enabled: true,
  };
}

/**
 * Read an attribute, tolerating case/snake differences. Consults the resolved
 * decision context FIRST (the canonical metric channel), then falls back to the
 * node's own raw props — buildDecisionContext emits a fixed allowlist, so custom
 * domain attributes (e.g. 'variance', 'cpi') only live on the raw node. Mirrors
 * the rules loader's custom-field fallback.
 */
function resolveAttr(
  ctx: Record<string, unknown>,
  props: Record<string, unknown>,
  attribute: string,
): unknown {
  const norm = normalizeAttr(attribute);
  if (attribute in ctx && ctx[attribute] != null) return ctx[attribute];
  for (const key of Object.keys(ctx)) {
    if (normalizeAttr(key) === norm && ctx[key] != null) return ctx[key];
  }
  if (attribute in props && props[attribute] != null) return props[attribute];
  for (const key of Object.keys(props)) {
    if (normalizeAttr(key) === norm && props[key] != null) return props[key];
  }
  return undefined;
}

function isNum(v: unknown): v is number {
  return typeof v === 'number' && !Number.isNaN(v);
}
function asNum(v: unknown): number | undefined {
  if (isNum(v)) return v;
  if (typeof v === 'string' && v.trim() !== '' && !Number.isNaN(Number(v))) return Number(v);
  return undefined;
}

/** Apply one operator. Numeric compare when both sides are numeric, else string. */
function testCondition(value: unknown, operator: string, threshold: number | string): boolean {
  const vNum = asNum(value);
  const tNum = asNum(threshold);
  const bothNum = vNum != null && tNum != null;
  switch (operator) {
    case '>':
      return bothNum ? vNum! > tNum! : false;
    case '<':
      return bothNum ? vNum! < tNum! : false;
    case '>=':
      return bothNum ? vNum! >= tNum! : false;
    case '<=':
      return bothNum ? vNum! <= tNum! : false;
    case '==':
      return bothNum ? vNum! === tNum! : String(value) === String(threshold);
    case '!=':
      return bothNum ? vNum! !== tNum! : String(value) !== String(threshold);
    default:
      return false;
  }
}

/** DomainRule severity -> finding severity (critical collapses into high). */
const SEVERITY_TO_FINDING: Record<Severity, 'low' | 'medium' | 'high'> = {
  low: 'low',
  medium: 'medium',
  high: 'high',
  critical: 'high',
};

/** Handoff action types: where an agent talks to other agents (a2a). */
const HANDOFF_TYPES = new Set(['trigger_agent', 'escalate']);

/**
 * Evaluate an agent's enabled DomainRules against a node. A rule fires when ALL
 * its conditions hold; each fired rule contributes one FiredRule PER action.
 * Conditions whose attribute can't be resolved are skipped (treated as not
 * holding), so a rule with an unresolvable condition simply doesn't fire.
 */
export async function evaluateDomainRules(agentId: string, node: ResolvedNode): Promise<FiredRule[]> {
  const pack = getDomainPack(agentId);
  if (!pack) return [];

  const ctx = await buildDecisionContext(node, asContextRule(node.props.ontologyClass as string | undefined));
  const fired: FiredRule[] = [];

  for (const rule of pack.rules) {
    if (!rule.enabled || rule.conditions.length === 0) continue;

    const observed: Record<string, unknown> = {};
    let allHold = true;
    for (const cond of rule.conditions) {
      const value = resolveAttr(ctx, node.props, cond.attribute);
      if (value === undefined) {
        // Attribute not resolvable for this node — the rule cannot fire.
        allHold = false;
        break;
      }
      observed[cond.attribute] = value;
      if (!testCondition(value, cond.operator, cond.threshold)) {
        allHold = false;
        break;
      }
    }
    if (!allHold) continue;

    for (const action of rule.actions) {
      fired.push({ rule, action, observed, severity: action.severity });
    }
  }

  return fired;
}

/** Derive an OpenProject WP id from a graph node id like "op-wp-1234". */
function workPackageId(nodeId: string): number | undefined {
  const m = nodeId.match(/op-wp-(\d+)/);
  return m ? Number(m[1]) : undefined;
}

/**
 * Commit fired rules: record (deduped) findings and collect a2a handoff targets.
 * The finding type is keyed per (agent, rule) so recordFinding's (type, nodeId)
 * dedup suppresses a standing breach instead of re-raising it. Returns the count
 * of NEW findings and the union of target agents from trigger_agent/escalate.
 */
export async function applyFiredRules(
  agentId: string,
  node: ResolvedNode,
  fired: FiredRule[],
): Promise<{ findings: number; handoffs: string[] }> {
  let findings = 0;
  const handoffs = new Set<string>();
  const wpId = workPackageId(node.id);

  for (const f of fired) {
    const evidence = Object.entries(f.observed).map(([metric, value]) => ({
      entityId: node.id,
      metric,
      value: String(value),
    }));
    const observedStr = evidence.map((e) => `${e.metric}=${e.value}`).join(', ');
    const body = `${f.action.message ?? f.rule.description ?? f.rule.name}` +
      (observedStr ? `\n\nObserved: ${observedStr}` : '');

    const { isNew } = await recordFinding({
      type: `${agentId}:${f.rule.id}`,
      agentId,
      severity: SEVERITY_TO_FINDING[f.severity],
      title: f.rule.name,
      body,
      nodeId: node.id,
      workPackageId: wpId,
      evidence,
    });
    if (isNew) findings++;

    if (HANDOFF_TYPES.has(f.action.type)) {
      for (const target of f.action.targetAgents ?? []) handoffs.add(target);
    }
  }

  return { findings, handoffs: [...handoffs] };
}
