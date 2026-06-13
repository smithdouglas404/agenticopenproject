/**
 * a2a cascade — bounded, deduped, event-triggered agent-to-agent collaboration.
 *
 * WHAT: Seeded with the relevant agents for a change, this runs each agent's
 * DomainRules on the node, records findings, broadcasts a fact for every attribute
 * a rule keyed on, and enqueues the NEXT layer of agents — the handoff targets
 * (trigger_agent / escalate) plus the subscribers of each broadcast attribute.
 * It repeats until the queue drains or the depth limit is hit.
 * WHY: This is the "agents talk to each other" mechanism, and it is the ONLY way
 * an agent runs besides being directly relevant to a change — there is no timer.
 *
 * THE GUARDS (why this can never become a costly loop):
 *   - depth cap: config.agents.maxCascadeDepth hops, hard stop.
 *   - per-cascade visited set: an (agentId, nodeId) pair runs AT MOST once.
 *   - cooldown: a (agentId, nodeId) that fired within cascadeCooldownMinutes is
 *     skipped (persisted in RuleState, survives restarts), so repeated events
 *     don't re-storm the same agents.
 * Together these bound the work to O(agents × nodes) regardless of edge cycles.
 */
import type { AgentFact } from '../domains/types.js';
import { getGraph } from '../../graph/falkor.js';
import type { ResolvedNode } from '../../rules/loader.js';
import { getState, setState, withinCooldown } from '../../rules/state.js';
import { config } from '../../config.js';
import { evaluateDomainRules, applyFiredRules, type FiredRule } from './ruleEval.js';
import { broadcastFact, subscribersFor } from './factBus.js';

/** Properties surfaced on a resolved node (mirrors the rules evaluator's set). */
const NODE_RETURN = `n.id AS id, n.name AS name, n.status AS status, n.priority AS priority,
  n.progress AS progress, n.assignee AS assignee, n.endDate AS endDate, n.source AS source,
  n.spentHours AS spentHours, n.estimatedHours AS estimatedHours, n.riskScore AS riskScore,
  n.spineClass AS spineClass, n.projectId AS projectId, n.workPackageId AS workPackageId`;

/**
 * Resolve a single node id into a ResolvedNode (id + scalar props). Returns null
 * when the node isn't in the graph (empty-graph degrade) or the query errors.
 */
export async function resolveNodeById(
  nodeId: string,
  ontologyClass?: string,
): Promise<ResolvedNode | null> {
  try {
    const rows = await getGraph().query<Record<string, unknown> & { id: string }>(
      `MATCH (n { id: $id }) RETURN ${NODE_RETURN} LIMIT 1`,
      { id: nodeId },
    );
    if (rows.length === 0) return null;
    const { id, ...rest } = rows[0];
    // Stamp the ontology class so buildDecisionContext can pick project metrics.
    if (ontologyClass && rest.ontologyClass == null) rest.ontologyClass = ontologyClass;
    return { id, props: rest };
  } catch {
    return null;
  }
}

/** Use a synthetic rule id per agent so cooldown state is keyed per agent+node. */
function cooldownRuleId(agentId: string): number {
  // Stable small int derived from the agent id (RuleState keys on a numeric ruleId).
  let h = 0;
  for (let i = 0; i < agentId.length; i++) h = (h * 31 + agentId.charCodeAt(i)) | 0;
  // Offset into a private band so it never collides with real OpenProject rule ids.
  return 900_000 + (Math.abs(h) % 90_000);
}

/** Whether this (agent, node) is cooling down from a recent cascade firing. */
async function inCooldown(agentId: string, nodeId: string): Promise<boolean> {
  if (config.agents.cascadeCooldownMinutes <= 0) return false;
  try {
    const state = await getState(cooldownRuleId(agentId), nodeId);
    return withinCooldown(state, config.agents.cascadeCooldownMinutes);
  } catch {
    return false;
  }
}

/** Stamp the cooldown clock for a (agent, node) that just fired. */
async function markFired(agentId: string, nodeId: string): Promise<void> {
  try {
    await setState(cooldownRuleId(agentId), nodeId, 1, new Date().toISOString());
  } catch {
    // Cooldown persistence is best-effort; the in-cascade visited set still bounds work.
  }
}

/** Outcome of a cascade run — useful for the smoke proof + the change entry point. */
export interface CascadeResult {
  agentsRun: number;
  findings: number;
  /** Ordered trace of who ran on what at which depth, and what they triggered. */
  path: Array<{ depth: number; agentId: string; nodeId: string; fired: number; handoffs: string[] }>;
  /** Agents that actually fired at least one rule (for the optional narrative pass). */
  firedAgents: string[];
}

/** Build the fact an agent broadcasts for one fired rule's keyed attributes. */
function factsFromFired(node: ResolvedNode, agentId: string, fired: FiredRule[]): AgentFact[] {
  const now = new Date().toISOString();
  const seen = new Set<string>();
  const facts: AgentFact[] = [];
  for (const f of fired) {
    for (const [attribute, value] of Object.entries(f.observed)) {
      if (seen.has(attribute)) continue;
      seen.add(attribute);
      facts.push({ entity: node.id, attribute, value, confidence: 1, byAgent: agentId, at: now });
    }
  }
  return facts;
}

/**
 * Run the a2a cascade. Seeds with `seedAgents` on `node`, then expands by handoff
 * targets + fact subscribers, bounded by depth + visited-set + cooldown. Returns
 * the run/finding counts and a trace. Never throws.
 */
export async function cascade(
  seedAgents: string[],
  node: ResolvedNode,
  depth = 0,
): Promise<CascadeResult> {
  const maxDepth = Math.max(0, config.agents.maxCascadeDepth);
  const visited = new Set<string>(); // `${agentId}::${nodeId}` — at most once per cascade
  const result: CascadeResult = { agentsRun: 0, findings: 0, path: [], firedAgents: [] };
  const firedSet = new Set<string>();

  // Layered BFS: each layer is the agents enqueued by the previous one.
  let layer: string[] = [...new Set(seedAgents)];
  for (let d = depth; layer.length > 0 && d <= maxDepth; d++) {
    const next = new Set<string>();

    for (const agentId of layer) {
      const key = `${agentId}::${node.id}`;
      if (visited.has(key)) continue; // dedup: never run the same agent+node twice
      visited.add(key);

      if (await inCooldown(agentId, node.id)) continue; // recently fired — suppress

      let fired: FiredRule[] = [];
      try {
        fired = await evaluateDomainRules(agentId, node);
      } catch {
        fired = [];
      }
      result.agentsRun++;

      if (fired.length === 0) {
        result.path.push({ depth: d, agentId, nodeId: node.id, fired: 0, handoffs: [] });
        continue;
      }

      // Record findings + collect a2a handoff targets.
      const { findings, handoffs } = await applyFiredRules(agentId, node, fired).catch(() => ({
        findings: 0,
        handoffs: [] as string[],
      }));
      result.findings += findings;
      if (!firedSet.has(agentId)) {
        firedSet.add(agentId);
        result.firedAgents.push(agentId);
      }
      await markFired(agentId, node.id);

      // Broadcast a fact per keyed attribute; subscribers join the next layer.
      const subscriberSet = new Set<string>();
      for (const fact of factsFromFired(node, agentId, fired)) {
        await broadcastFact(fact);
        for (const sub of subscribersFor(fact.attribute)) subscriberSet.add(sub);
      }

      const enqueued = new Set<string>([...handoffs, ...subscriberSet]);
      enqueued.delete(agentId); // don't re-enqueue self
      for (const t of enqueued) {
        if (!visited.has(`${t}::${node.id}`)) next.add(t);
      }

      result.path.push({ depth: d, agentId, nodeId: node.id, fired: fired.length, handoffs: [...enqueued] });
    }

    layer = [...next];
  }

  return result;
}
