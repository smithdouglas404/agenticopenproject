/**
 * Proactive reflection — the autonomy layer on top of the reactive cascade.
 *
 * The reactive engine (events/*) flags rule BREACHES. This layer is different and
 * is what the product is actually about: each agent is an autonomous, STATEFUL
 * entity (Letta-backed, with Mem0/graph memory) that reasons over the knowledge
 * graph looking for OPPORTUNITIES and risks — not just threshold violations — and
 * does so because (a) a change happened, (b) a PEER AGENT handed off to it (the
 * a2a conversation), or (c) it reflects on its accumulated memory. There is no
 * central orchestrator computing for the agents and no blind cron: reflection is
 * always driven by a real stimulus, so it is proactive in behavior yet bounded in
 * cost.
 *
 * Statefulness: when Letta is configured each roster agent has a persistent Letta
 * agent (see src/letta), so reflection routes through it and the agent REMEMBERS.
 * Without Letta it falls back to a direct Claude call seeded with memory recall —
 * still grounded, just not stateful across turns.
 */
import { z } from 'zod';
import { callLLMJson } from '../../llm/claude.js';
import { lettaConfigured, getRosterAgentId, sendToAgent } from '../../letta/client.js';
import { searchMemory, recordEpisode } from '../../memory/index.js';
import { recordFinding } from '../../store/findings.js';
import { buildDecisionContext } from '../../rules/decisionContext.js';
import type { ResolvedNode } from '../../rules/loader.js';
import type { Rule } from '../../rules/types.js';
import { getAgent } from '../roster.js';
import { getDomainPack } from '../domains/index.js';
import { config } from '../../config.js';

/** A peer-agent stimulus — turns a handoff into a directed conversation. */
export interface ReflectionStimulus {
  /** The agent that handed off to this one (the conversation partner). */
  fromAgent: string;
  /** What it observed, e.g. "budget_variance crossed 20% (critical)". */
  observation: string;
}

const OpportunityOutput = z.object({
  opportunities: z
    .array(
      z.object({
        title: z.string(),
        insight: z.string(),
        recommendation: z.string().optional(),
        severity: z.enum(['low', 'medium', 'high']).default('low'),
        confidence: z.number().min(0).max(1).optional(),
        relatedNodeId: z.string().optional(),
        evidence: z
          .array(z.object({ entityId: z.string(), metric: z.string(), value: z.string() }))
          .max(5)
          .optional(),
      }),
    )
    .max(5),
});

function extractJson(text: string): unknown | null {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end <= start) return null;
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch {
    return null;
  }
}

function ctxRule(ontologyClass?: string): Rule {
  return {
    id: 0, project_id: null, ontology_class: ontologyClass ?? '', metric: '',
    operator: 'eq', threshold: null, threshold2: null, severity: 'info',
    cooldown_minutes: 0, action_kind: 'alert', notify_openproject: false,
    notify_kyndral: false, enabled: true,
  };
}

/** Build the agent's reflection prompt: its lens + the entity + memory + the peer stimulus. */
async function buildReflectionPrompt(
  agentId: string,
  node: ResolvedNode,
  stimulus?: ReflectionStimulus,
): Promise<{ system: string; user: string }> {
  const agent = getAgent(agentId);
  const pack = getDomainPack(agentId);
  const capabilities = pack?.capabilities?.length
    ? `Your capabilities: ${pack.capabilities.join('; ')}.`
    : '';

  const ctx = await buildDecisionContext(node, ctxRule(node.props?.ontologyClass as string | undefined)).catch(
    () => ({}) as Record<string, unknown>,
  );
  const metricLines = Object.entries(ctx)
    .filter(([k]) => k !== 'now')
    .map(([k, v]) => `  - ${k}: ${String(v)}`)
    .join('\n');

  // Memory recall — what this agent already knows about this entity (statefulness).
  const recalled = await searchMemory(`${agentId} ${node.id}`, { subjectNodeId: node.id, limit: 5 }).catch(
    () => [],
  );
  const memoryLines = recalled.length
    ? recalled.map((m) => `  - ${m.content ?? JSON.stringify(m).slice(0, 160)}`).join('\n')
    : '  (no prior memory on this entity)';

  const stimulusLine = stimulus
    ? `\n\nA PEER AGENT REACHED OUT: the ${stimulus.fromAgent} agent observed: "${stimulus.observation}". ` +
      `Consider whether, through YOUR domain lens, this creates an opportunity or a risk worth surfacing.`
    : `\n\nReflect proactively: is there an opportunity or emerging risk on this entity that your domain should surface now?`;

  const system =
    `You are the ${agent?.name ?? agentId} — an autonomous PPM agent. ${agent?.purpose ?? ''} ${capabilities}\n` +
    `You reason over a knowledge graph to find OPPORTUNITIES and emerging risks — not just threshold breaches. ` +
    `Only surface something genuinely supported by the data below; if there's nothing, return an empty array. ` +
    `Never invent metrics. Respond with ONLY this JSON: ` +
    `{"opportunities":[{"title","insight","recommendation","severity":"low|medium|high","confidence":0..1,"relatedNodeId","evidence":[{"entityId","metric","value"}]}]} (max 3).`;

  const user =
    `ENTITY: ${node.id}\n\nGRAPH METRICS:\n${metricLines || '  (none resolvable)'}` +
    `\n\nWHAT YOU REMEMBER:\n${memoryLines}` +
    stimulusLine;

  return { system, user };
}

/**
 * Reflect through one agent on one entity. Routes through the agent's stateful
 * Letta agent when configured (so it remembers), else a direct Claude call.
 * Records any opportunities as findings (type 'opportunity') and writes a memory
 * episode so the agent's state grows. Returns the number of NEW findings. Never throws.
 */
export async function reflectForOpportunities(
  agentId: string,
  node: ResolvedNode,
  stimulus?: ReflectionStimulus,
): Promise<number> {
  if (!config.agents.proactive) return 0;
  try {
    const { system, user } = await buildReflectionPrompt(agentId, node, stimulus);

    let raw: unknown | null = null;
    if (lettaConfigured()) {
      const lettaId = await getRosterAgentId(agentId).catch(() => null);
      if (lettaId) {
        const reply = await sendToAgent(lettaId, `${system}\n\n${user}`).catch(() => '');
        raw = reply ? extractJson(reply) : null;
      }
    }
    if (!raw) {
      raw = await callLLMJson(system, user, { maxTokens: 1200 }).catch(() => null);
    }

    const parsed = OpportunityOutput.safeParse(raw);
    if (!parsed.success) return 0;

    let n = 0;
    for (const op of parsed.data.opportunities) {
      const wpId = (op.relatedNodeId ?? node.id).match(/op-wp-(\d+)/)?.[1];
      const narrative = op.recommendation ? `${op.insight}\n\n**Opportunity:** ${op.recommendation}` : op.insight;
      const { isNew } = await recordFinding({
        type: 'opportunity',
        agentId,
        severity: op.severity,
        title: op.title,
        body: op.insight,
        narrative,
        nodeId: op.relatedNodeId ?? node.id,
        workPackageId: wpId ? Number(wpId) : undefined,
        evidence: op.evidence,
        confidence: op.confidence,
      });
      if (isNew) n++;
    }

    // Grow the agent's memory — this is what makes it stateful/proactive over time.
    if (n > 0) {
      await recordEpisode({
        content: `${agentId} reflected on ${node.id}${stimulus ? ` (prompted by ${stimulus.fromAgent})` : ''}: ${n} opportunity/risk insight(s)`,
        source: `agent:${agentId}`,
        subjectNodeId: node.id,
      }).catch(() => {});
    }
    return n;
  } catch (err: any) {
    console.warn(`[autonomy] reflection for ${agentId} on ${node.id} failed: ${err?.message ?? err}`);
    return 0;
  }
}
