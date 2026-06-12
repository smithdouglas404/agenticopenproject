/**
 * ZEN decision core — the richer evaluation path for kind:'decision' rules.
 *
 * WHAT: Evaluates a rule's GoRules JDM graph (`rule.jdm`) against each node's
 * decision context (decisionContext.ts) using an in-process ZenEngine, normalizes
 * the JDM's DecisionOutput (object or array), and emits RuleBreach[] — honoring
 * the SAME per-(rule,node) cooldown/state machine the threshold path uses.
 * WHY: Threshold operators express simple comparisons; JDM decision tables express
 * multi-input, multi-output policy (severity tiers, collected breaches) authored
 * outside code. This module degrades gracefully: a ZEN/compile error on a node is
 * warned and skipped — it NEVER throws into the sweep.
 *
 *   evaluateDecisionRule(rule, nodes) -> RuleBreach[]
 */
import { createHash } from 'node:crypto';
import { ZenEngine, type ZenDecision } from '@gorules/zen-engine';
import { config } from '../config.js';
import type { Rule, RuleBreach, RuleSeverity, DecisionOutput } from './types.js';
import { resolveMetric, type ResolvedNode } from './loader.js';
import { buildDecisionContext } from './decisionContext.js';
import { getState, setState, withinCooldown } from './state.js';

// ---------------------------------------------------------------------------
// Engine + compiled-decision lifecycle
// ---------------------------------------------------------------------------

let engine: ZenEngine | null = null;

/** Lazily create the singleton ZenEngine (one native engine per process). */
function getEngine(): ZenEngine {
  if (!engine) engine = new ZenEngine();
  return engine;
}

/** Cache of compiled decisions, keyed by `${rule.id}:${hash(jdm)}`. */
const decisionCache = new Map<string, { hash: string; decision: ZenDecision }>();

/** Stable hash of the JDM object so a changed graph invalidates its cache entry. */
function hashJdm(jdm: unknown): string {
  return createHash('sha1').update(JSON.stringify(jdm)).digest('hex');
}

/**
 * Get (compiling once) the ZenDecision for a rule. Re-compiles and replaces the
 * cache entry when the rule's JDM hash changes; reuses it otherwise.
 */
function getDecision(rule: Rule): ZenDecision {
  const hash = hashJdm(rule.jdm);
  const cached = decisionCache.get(String(rule.id));
  if (cached && cached.hash === hash) return cached.decision;
  // Pass the JDM as a JS OBJECT (not a JSON string) — the verified ZEN API.
  const decision = getEngine().createDecision(rule.jdm as object);
  decisionCache.set(String(rule.id), { hash, decision });
  return decision;
}

/** Dispose the ZEN engine + cached decisions for a clean process shutdown. */
export function disposeZen(): void {
  decisionCache.clear();
  if (engine) {
    engine.dispose();
    engine = null;
  }
}

// ---------------------------------------------------------------------------
// Result normalization
// ---------------------------------------------------------------------------

/** Coerce an arbitrary JDM result into a list of DecisionOutput candidates. */
function normalizeOutputs(result: unknown): DecisionOutput[] {
  if (Array.isArray(result)) {
    return result.filter((r): r is DecisionOutput => !!r && typeof r === 'object');
  }
  if (result && typeof result === 'object') return [result as DecisionOutput];
  return [];
}

/** Narrow an unknown severity to a RuleSeverity, else undefined. */
function asSeverity(value: unknown): RuleSeverity | undefined {
  return value === 'info' || value === 'warning' || value === 'critical' ? value : undefined;
}

// ---------------------------------------------------------------------------
// Evaluation
// ---------------------------------------------------------------------------

let zenDisabledWarned = false;

/**
 * Evaluate a kind:'decision' rule against resolved nodes. For each node: build
 * the decision context, evaluate the JDM, normalize outputs, and for every output
 * with breach===true emit a RuleBreach (subject to cooldown). Any ZEN error on a
 * node is warned and skipped. Returns the breaches across all nodes.
 */
export async function evaluateDecisionRule(rule: Rule, nodes: ResolvedNode[]): Promise<RuleBreach[]> {
  if (!config.rules.zenEnabled) {
    if (!zenDisabledWarned) {
      console.warn('[rules] ZEN decision core disabled (RULES_ZEN_ENABLED=0); skipping decision rules');
      zenDisabledWarned = true;
    }
    return [];
  }
  if (rule.jdm == null) {
    console.warn(`[rules] decision rule ${rule.id} has no jdm; skipping`);
    return [];
  }

  const breaches: RuleBreach[] = [];

  for (const node of nodes) {
    try {
      const decision = getDecision(rule);
      const ctx = await buildDecisionContext(node, rule);
      const evaluated = await decision.evaluate(ctx);
      const outputs = normalizeOutputs((evaluated as { result?: unknown }).result);

      // A node fires if ANY output breaches. Cooldown is per (rule, node), so one
      // state read/update covers all of this node's outputs.
      const firing = outputs.filter((o) => o.breach === true);
      if (firing.length === 0) {
        // Non-firing pass: still record observed value so history stays warm.
        await setState(rule.id, node.id, observedFor(firing[0], ctx, rule) ?? 'n/a');
        continue;
      }

      const state = await getState(rule.id, node.id);
      if (withinCooldown(state, rule.cooldown_minutes)) {
        // Suppressed by cooldown: update value but keep the lastFiredAt clock.
        await setState(rule.id, node.id, observedFor(firing[0], ctx, rule) ?? 'n/a');
        continue;
      }

      let firedValue: number | string = 'n/a';
      for (const out of firing) {
        const observed = await observedForAsync(out, ctx, rule, node);
        firedValue = observed;
        breaches.push({
          rule,
          nodeId: node.id,
          ontologyClass: rule.ontology_class,
          metric: out.metric ?? rule.metric,
          observedValue: observed,
          severity: asSeverity(out.severity) ?? rule.severity,
          message: out.message ?? buildDecisionMessage(rule, node, out, observed),
        });
      }
      // Firing updates BOTH the value and the cooldown clock.
      await setState(rule.id, node.id, firedValue, new Date().toISOString());
    } catch (err) {
      console.warn(`[rules] decision rule ${rule.id} ZEN eval failed on ${node.id}: ${(err as Error).message}`);
      continue;
    }
  }

  return breaches;
}

// ---------------------------------------------------------------------------
// Observed-value resolution + messaging
// ---------------------------------------------------------------------------

/** Synchronous observed value: output.value, else the ctx field named by metric. */
function observedFor(
  out: DecisionOutput | undefined,
  ctx: Record<string, unknown>,
  rule: Rule,
): number | string | undefined {
  if (out?.value !== undefined) return out.value;
  const key = out?.metric ?? rule.metric;
  const fromCtx = ctx[key];
  if (typeof fromCtx === 'number' || typeof fromCtx === 'string') return fromCtx;
  return undefined;
}

/**
 * Observed value with a graph fallback: output.value, else the ctx field, else a
 * full metric resolution against the node, else 'n/a'.
 */
async function observedForAsync(
  out: DecisionOutput,
  ctx: Record<string, unknown>,
  rule: Rule,
  node: ResolvedNode,
): Promise<number | string> {
  const direct = observedFor(out, ctx, rule);
  if (direct !== undefined) return direct;
  try {
    const resolved = await resolveMetric(out.metric ?? rule.metric, node);
    if (resolved !== undefined) return resolved;
  } catch {
    // fall through to 'n/a'
  }
  return 'n/a';
}

/** Default human-readable message when the JDM omits one. */
function buildDecisionMessage(
  rule: Rule,
  node: ResolvedNode,
  out: DecisionOutput,
  observed: number | string,
): string {
  const name = (node.props.name as string | undefined) ?? node.id;
  const cls = rule.ontology_class.includes(':') ? rule.ontology_class.split(':').pop()! : rule.ontology_class;
  const metric = out.metric ?? rule.metric;
  return `${cls} "${name}" decision rule #${rule.id} breached (${metric} = ${observed})`;
}
