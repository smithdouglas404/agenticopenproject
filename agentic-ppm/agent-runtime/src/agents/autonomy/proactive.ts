/**
 * Optional proactive reflection — autonomy WITHOUT a central orchestrator or a
 * blind portfolio cron.
 *
 * `proactiveReflect()` lets the agents look at the knowledge graph for
 * opportunities on their own. It is STIMULUS-driven, not a clock: it reflects
 * only over RECENTLY-ACTIVE entities (recently updated / recently the subject of
 * findings), and only the agents relevant to each entity reflect. It is OFF by
 * default (config.agents.proactiveScanMinutes = 0); it exists as a capability the
 * runtime or an operator invokes (npm run agents:reflect), or that the user can
 * opt into on a sparse cadence. It never re-evaluates the whole portfolio and
 * never forces an agent to act — each agent decides whether it has something to
 * surface.
 *
 * This is the "constantly thinking" behaviour, kept bounded: agents reflect when
 * there is fresh activity to reflect on, not on a timer that costs money idling.
 */
import { getGraph } from '../../graph/falkor.js';
import { config } from '../../config.js';
import { agentsForChange } from '../events/relevance.js';
import { resolveNodeById } from '../events/collaboration.js';
import { reflectForOpportunities } from './reflection.js';
import type { ChangeEvent } from '../domains/types.js';

/** Pull recently-updated work items / projects from the graph (the activity signal). */
async function recentlyActiveNodes(limit: number): Promise<{ id: string; spineClass?: string }[]> {
  try {
    const rows = await getGraph().query<{ id: string; spineClass?: string }>(
      `MATCH (n)
       WHERE n.spineClass IN ['Epic','Feature','Story','Task','Issue','Milestone','Risk','Objective']
         AND n.updatedAt IS NOT NULL
       RETURN n.id AS id, n.spineClass AS spineClass
       ORDER BY n.updatedAt DESC
       LIMIT ${Math.max(1, Math.min(limit, 100))}`,
    );
    return rows;
  } catch {
    return [];
  }
}

/**
 * Reflect over recently-active entities. For each, the relevance gate picks the
 * agents that watch its attributes and they reflect for opportunities (stateful,
 * via Letta when configured). Bounded by `limit`. Returns counts. Never throws.
 */
export async function proactiveReflect(opts?: { limit?: number }): Promise<{ entities: number; insights: number }> {
  if (!config.agents.proactive) return { entities: 0, insights: 0 };
  const limit = opts?.limit ?? 20;
  const nodes = await recentlyActiveNodes(limit);
  let insights = 0;
  let entities = 0;

  for (const n of nodes) {
    const ontologyClass = n.spineClass ? `pm:${n.spineClass}` : undefined;
    // Treat "recently active" as a change over the node's own key attributes so
    // the SAME relevance gate decides who reflects — no separate routing.
    const change: ChangeEvent = {
      nodeId: n.id,
      ontologyClass,
      changed: { status: { prev: null, next: null }, progress: { prev: null, next: null } },
      source: 'proactive-reflect',
    };
    const relevant = agentsForChange(change);
    if (relevant.length === 0) continue;

    const resolved = await resolveNodeById(n.id, ontologyClass);
    if (!resolved) continue;
    entities++;
    for (const agentId of relevant) {
      insights += await reflectForOpportunities(agentId, resolved).catch(() => 0);
    }
  }
  console.log(`[autonomy] proactiveReflect: ${entities} active entit(y/ies), ${insights} opportunity insight(s)`);
  return { entities, insights };
}
