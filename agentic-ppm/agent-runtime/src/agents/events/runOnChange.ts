/**
 * runAgentsForChange — THE entry point of the event-driven agent engine.
 *
 * WHAT: A change arrives (from the webhook). We (1) compute the RELEVANT agents
 * via the relevance gate, (2) seed the deterministic a2a cascade with them on the
 * changed node, and (3) optionally run a focused LLM narrative pass for the agents
 * that actually fired — never the whole roster, to keep cost down.
 * WHY: This replaces the cron/polling sweep for domain + reasoning agents: an agent
 * runs ONLY because a relevant change touched it or another agent handed off to it.
 * The sweep stays as a safety net (wired separately); this is the live path.
 * It never throws into its caller — the webhook is fire-and-forget.
 */
import type { ChangeEvent } from '../domains/types.js';
import { config } from '../../config.js';
import { getAgent, type AgentDomain } from '../roster.js';
import { runReasoningAgent } from '../reasoningAgents.js';
import { buildDecisionContext } from '../../rules/decisionContext.js';
import type { Rule } from '../../rules/types.js';
import { agentsForChange } from './relevance.js';
import { cascade, resolveNodeById } from './collaboration.js';
import { reflectForOpportunities } from '../autonomy/reflection.js';

/** Minimal Rule shim so buildDecisionContext can resolve the node's metrics. */
function contextRule(ontologyClass: string | undefined): Rule {
  return {
    id: 0, project_id: null, ontology_class: ontologyClass ?? '', metric: '',
    operator: 'eq', threshold: null, threshold2: null, severity: 'info',
    cooldown_minutes: 0, action_kind: 'alert', notify_openproject: false,
    notify_kyndral: false, enabled: true,
  };
}

/**
 * Build the compact, single-entity context string the focused LLM narrative pass
 * sees. It's the resolved decision context (id, class, metrics) for ONE node, plus
 * the attributes that changed — far smaller than the whole-portfolio sweep context.
 */
async function buildEntityContext(change: ChangeEvent): Promise<string> {
  const node = await resolveNodeById(change.nodeId, change.ontologyClass);
  const ctx = node
    ? await buildDecisionContext(node, contextRule(change.ontologyClass)).catch(() => null)
    : null;

  const changedLines = Object.entries(change.changed ?? {})
    .map(([k, v]) => `  - ${k}: ${String(v?.prev)} -> ${String(v?.next)}`)
    .join('\n');

  const metricLines = ctx
    ? Object.entries(ctx)
        .filter(([k]) => k !== 'now')
        .map(([k, v]) => `  - ${k}: ${String(v)}`)
        .join('\n')
    : '  (entity not resolvable in the graph)';

  return (
    `FOCUSED ENTITY: ${change.nodeId}` +
    (change.ontologyClass ? ` (${change.ontologyClass})` : '') +
    `\n\nCHANGED ATTRIBUTES:\n${changedLines || '  (none reported)'}` +
    `\n\nRESOLVED METRICS:\n${metricLines}` +
    `\n\nAnalyze ONLY this entity through your domain lens. Report a finding only if ` +
    `your domain's data clearly supports one; otherwise return an empty findings array.`
  );
}

/**
 * Run the agents for a single change. Returns how many agents ran and how many
 * NEW findings were recorded across the deterministic cascade. Never throws.
 */
export async function runAgentsForChange(
  change: ChangeEvent,
): Promise<{ agentsRun: number; findings: number }> {
  if (!config.agents.eventDriven) return { agentsRun: 0, findings: 0 };

  try {
    // 1. RELEVANCE GATE — only agents that watch a changed attribute.
    const seed = agentsForChange(change);
    if (seed.length === 0) return { agentsRun: 0, findings: 0 };

    // 2. Resolve the focused node; degrade to a props-only node if not in graph.
    const node =
      (await resolveNodeById(change.nodeId, change.ontologyClass)) ??
      { id: change.nodeId, props: { ontologyClass: change.ontologyClass } };

    // 3. Deterministic a2a cascade (bounded + deduped + cooldown-gated).
    const run = await cascade(seed, node);

    console.log(
      `[a2a] change ${change.nodeId}: seeded [${seed.join(', ')}] -> ` +
        `${run.agentsRun} agent-run(s), ${run.findings} new finding(s); ` +
        `cascade path: ${run.path.map((p) => `${p.agentId}@d${p.depth}(fired=${p.fired})`).join(' -> ')}`,
    );

    // 3b. AUTONOMY / a2a CONVERSATION — proactive opportunity reflection.
    //     Beyond rule breaches: each agent that fired reflects (statefully, via
    //     Letta when configured) for OPPORTUNITIES on this entity, and every
    //     handoff edge becomes a directed conversation — the target agent
    //     reflects in light of what the originating agent observed. Bounded by
    //     the cascade's own visited/cooldown guards (only fired agents + their
    //     direct handoff targets reflect), gated by config.agents.proactive.
    if (config.agents.proactive) {
      const reflected = new Set<string>();
      for (const step of run.path) {
        if (step.fired === 0) continue;
        // The agent that fired reflects on its own finding (deeper opportunity).
        if (!reflected.has(step.agentId)) {
          reflected.add(step.agentId);
          await reflectForOpportunities(step.agentId, node).catch(() => 0);
        }
        // Each peer it handed off to reflects on the stimulus (the conversation).
        for (const target of step.handoffs) {
          const key = `${target}<-${step.agentId}`;
          if (reflected.has(key)) continue;
          reflected.add(key);
          await reflectForOpportunities(target, node, {
            fromAgent: step.agentId,
            observation: `fired ${step.fired} rule(s) on ${node.id}`,
          }).catch(() => 0);
        }
      }
    }

    // 4. OPTIONAL focused LLM narrative — only for agents that actually fired,
    //    on this one entity (cost-bounded). Gated by config; never fatal.
    if (config.agents.llmNarrative && run.firedAgents.length > 0) {
      const context = await buildEntityContext(change).catch(() => '');
      if (context) {
        for (const agentId of run.firedAgents) {
          const agent: AgentDomain | undefined = getAgent(agentId);
          if (!agent) continue;
          await runReasoningAgent(agent, context).catch((err) =>
            console.warn(`[a2a] narrative pass for ${agentId} failed: ${err.message}`),
          );
        }
      }
    }

    return { agentsRun: run.agentsRun, findings: run.findings };
  } catch (err: any) {
    console.warn(`[a2a] runAgentsForChange failed for ${change.nodeId}: ${err?.message ?? err}`);
    return { agentsRun: 0, findings: 0 };
  }
}

/**
 * Map an OpenProject webhook work-package payload to a ChangeEvent. Returns null
 * when there's no resolvable node id. When the webhook gives no field-level diff,
 * `changed` is seeded with the WP's key attributes (prev=next=current value) so the
 * relevance gate can still match the agents that watch those attributes.
 */
export function buildChangeFromWebhook(payload: {
  nodeId?: string;
  ontologyClass?: string;
  changed?: Record<string, { prev: unknown; next: unknown }>;
  attributes?: Record<string, unknown>;
  source?: string;
}): ChangeEvent | null {
  if (!payload.nodeId) return null;
  let changed = payload.changed;
  if (!changed || Object.keys(changed).length === 0) {
    changed = {};
    for (const [k, v] of Object.entries(payload.attributes ?? {})) {
      changed[k] = { prev: v, next: v };
    }
  }
  return {
    nodeId: payload.nodeId,
    ontologyClass: payload.ontologyClass,
    changed,
    source: payload.source ?? 'openproject-webhook',
  };
}
