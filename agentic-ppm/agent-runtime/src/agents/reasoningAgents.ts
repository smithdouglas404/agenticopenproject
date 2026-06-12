/**
 * Multi-agent reasoning — promotes every roster agent to a real reasoning agent.
 *
 * Each agent looks at the portfolio through its own domain lens and produces
 * findings/recommendations, reasoning THROUGH its stateful Letta agent when
 * configured (so it remembers), else via a direct Claude call. Findings are
 * deduped + recorded + (optionally) published as Agent Alerts — same pipeline
 * the detectors use, so they show in the console and OpenProject.
 *
 * Strategic PMO is excluded here (it's handled by the per-project assessor).
 * Agents whose domain data isn't in the graph yet (e.g. FinOps with no cost
 * data) correctly return nothing — honest, not noisy.
 */
import { z } from 'zod';
import { getGraph } from '../graph/falkor.js';
import { callLLMJson } from '../llm/claude.js';
import { lettaConfigured, getRosterAgentId, sendToAgent } from '../letta/client.js';
import { recordFinding, setFindingStatus, listFindings, type StoredFinding } from '../store/findings.js';
import { writeFinding, type AlertSeverity } from '../inbox/inbox.js';
import { validateFinding, checkContradictions, type ContradictionInput } from '../grounding/validate.js';
import { recordPrediction, severityAdjustment } from '../learning/outcomes.js';
import { AGENT_ROSTER, type AgentDomain } from './roster.js';
import { config } from '../config.js';

const AgentOutput = z.object({
  findings: z
    .array(
      z.object({
        title: z.string(),
        severity: z.enum(['low', 'medium', 'high']),
        body: z.string(),
        recommendation: z.string().optional(),
        relatedNodeId: z.string().optional(),
        // Evidence citations — STRONGLY prompted; validated against the graph
        // before the finding is recorded (grounding/validate.ts).
        evidence: z
          .array(z.object({ entityId: z.string(), metric: z.string(), value: z.string() }))
          .max(5)
          .optional(),
        confidence: z.number().min(0).max(1).optional(),
      }),
    )
    .max(8),
});

const SEVERITY_TO_ALERT: Record<'low' | 'medium' | 'high', AlertSeverity> = {
  low: 'notification',
  medium: 'warning',
  high: 'alarm',
};

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

/** Compact portfolio snapshot every reasoning agent sees. */
async function buildPortfolioContext(): Promise<string> {
  const graph = getGraph();
  const projects = await graph.query<{ id: string; name: string; status: string }>(
    `MATCH (p:Project) RETURN p.id AS id, p.name AS name, p.status AS status LIMIT 50`,
  );
  const items = await graph.query<{
    id: string; name: string; type: string; status: string; priority: string;
    progress: number; assignee: string; endDate: string; source: string;
  }>(
    `MATCH (w) WHERE w.spineClass IN ['Epic','Feature','Story','Task','Issue','Milestone','Risk','Objective']
     RETURN w.id AS id, w.name AS name, w.spineClass AS type, w.status AS status,
            w.priority AS priority, w.progress AS progress, w.assignee AS assignee,
            w.endDate AS endDate, w.source AS source
     LIMIT 300`,
  );
  const projLines = projects.map((p) => `- ${p.name} (${p.id}) status=${p.status ?? 'n/a'}`).join('\n');
  const itemLines = items
    .map(
      (w) =>
        `- ${w.type} "${w.name}" (${w.id}) status=${w.status ?? 'n/a'} priority=${w.priority ?? 'n/a'} ` +
        `progress=${w.progress ?? 0}% assignee=${w.assignee ?? 'unassigned'} due=${w.endDate ?? 'n/a'} source=${w.source ?? 'openproject'}`,
    )
    .join('\n');
  return `PROJECTS (${projects.length}):\n${projLines}\n\nWORK ITEMS (${items.length}):\n${itemLines}`;
}

function systemPromptFor(agent: AgentDomain): string {
  return (
    `You are the ${agent.name} (domain: ${agent.domain}).\n` +
    `${agent.purpose}\n\n` +
    `Analyze ONLY your domain in the portfolio below and report concrete, ` +
    `evidence-based findings with a recommended action. Every finding SHOULD cite ` +
    `evidence rows pointing at real entity ids from the context — ` +
    `evidence:[{"entityId":"op-wp-42","metric":"progress","value":"40"}] (max 5 rows, ` +
    `values copied from the context, never invented). A finding about a specific ` +
    `item MUST set relatedNodeId to that item's id (e.g. op-wp-42). Include ` +
    `"confidence" (0-1) for each finding. If your confidence in a finding would be ` +
    `below 0.5, or your domain's data is not present in the portfolio (e.g. no ` +
    `cost, OKR, or readiness data), return no finding for it — insufficient data ` +
    `means abstain, not guess.\n\n` +
    `Respond with ONLY this JSON: {"findings":[{"title","severity":"low|medium|high",` +
    `"body","recommendation","relatedNodeId","evidence":[{"entityId","metric","value"}],` +
    `"confidence":0.0}]} (max 5 findings; an empty array is a valid answer).`
  );
}

/** Run one reasoning agent; returns the NEW findings it recorded (post-grounding). */
export async function runReasoningAgent(agent: AgentDomain, context: string): Promise<StoredFinding[]> {
  const system = systemPromptFor(agent);

  let raw: unknown | null = null;
  if (lettaConfigured()) {
    const id = await getRosterAgentId(agent.id);
    if (id) {
      const reply = await sendToAgent(id, `${system}\n\n${context}`);
      raw = reply ? extractJson(reply) : null;
    }
  }
  if (!raw) {
    raw = await callLLMJson(system, context, { maxTokens: 1500 }).catch(() => null);
  }

  const parsed = AgentOutput.safeParse(raw);
  if (!parsed.success) return [];

  const recorded: StoredFinding[] = [];
  for (const f of parsed.data.findings) {
    // GROUNDING gate: entity-existence + claim-evidence consistency. Findings
    // that reference entities not in the graph are dropped, not downgraded.
    const grounding = await validateFinding({
      title: f.title,
      severity: f.severity,
      relatedNodeId: f.relatedNodeId,
      evidence: f.evidence,
      confidence: f.confidence,
    });
    if (!grounding.ok) {
      console.warn(
        `[agent:${agent.id}] dropped ungrounded finding "${f.title}": ` +
          (grounding.violations.join('; ') || `confidence ${grounding.confidence} below threshold`),
      );
      continue;
    }

    const wpId = f.relatedNodeId?.match(/op-wp-(\d+)/)?.[1];
    const narrative = f.recommendation ? `${f.body}\n\n**Next:** ${f.recommendation}` : f.body;
    const { finding, isNew } = await recordFinding({
      type: agent.id,
      agentId: agent.id,
      severity: f.severity,
      title: f.title,
      body: f.body,
      narrative,
      nodeId: f.relatedNodeId,
      workPackageId: wpId ? Number(wpId) : undefined,
      evidence: f.evidence,
      confidence: grounding.confidence,
    });
    if (!isNew) continue;
    recorded.push(finding);

    // LEARNING: log the call as a prediction so the outcome loop can score it.
    await recordPrediction({
      id: finding.id,
      type: agent.id,
      agentId: agent.id,
      severity: f.severity,
      nodeId: f.relatedNodeId,
      workPackageId: wpId ? Number(wpId) : undefined,
      recommendation: f.recommendation,
    }).catch((err) => console.warn(`[agent:${agent.id}] prediction record failed: ${err.message}`));

    if (config.detectors.publish) {
      try {
        // Track-record weighting: a poor resolved-prediction record downgrades
        // the PUBLISHED severity one notch (the stored finding keeps its own).
        const tuned = await severityAdjustment(agent.id, f.severity);
        const note = tuned.adjusted ? `\n\n_${tuned.note}_` : '';
        const alertWpId = await writeFinding({
          title: `${agent.name}: ${f.title}`,
          body: `${narrative}${note}\n\nAgent: ${agent.id} · Finding: ${finding.id}`,
          severity: SEVERITY_TO_ALERT[tuned.severity],
          relatedWorkPackageId: wpId ? Number(wpId) : undefined,
        });
        await setFindingStatus(finding.id, 'published', { alertWpId });
      } catch (err: any) {
        console.warn(`[agent:${agent.id}] publish failed: ${err.message}`);
      }
    }
  }
  return recorded;
}

function toContradictionInput(f: StoredFinding): ContradictionInput {
  return {
    id: f.id,
    agentId: f.agentId,
    severity: f.severity,
    title: f.title,
    nodeId: f.nodeId || undefined,
    text: [f.title, f.body, f.narrative ?? ''].join(' '),
  };
}

/** Run every reasoning agent (except Strategic PMO, handled by the project assessor). */
export async function runAgents(): Promise<number> {
  if (!config.reasoning.enabled) return 0;
  const context = await buildPortfolioContext();
  const fresh: StoredFinding[] = [];
  for (const agent of AGENT_ROSTER) {
    if (agent.id === 'strategic-pmo') continue;
    try {
      fresh.push(...(await runReasoningAgent(agent, context)));
    } catch (err: any) {
      console.warn(`[agent:${agent.id}] reasoning failed: ${err.message}`);
    }
  }

  // Cross-agent reconciliation: flag opposing recommendations + high-severity
  // convergence on the same node, across the new findings AND the open ones.
  try {
    const open = await listFindings({ status: 'published' });
    const contradictions = await checkContradictions(
      fresh.map(toContradictionInput),
      open.filter((f) => f.type !== 'AgentContradiction').map(toContradictionInput),
    );
    if (contradictions.length > 0) {
      console.log(`[agents] flagged ${contradictions.length} contradiction/convergence signal(s)`);
    }
  } catch (err: any) {
    console.warn(`[agents] contradiction check failed: ${err.message}`);
  }

  return fresh.length;
}
