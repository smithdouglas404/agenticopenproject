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
import { recordFinding, setFindingStatus } from '../store/findings.js';
import { writeFinding, type AlertSeverity } from '../inbox/inbox.js';
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
    `evidence-based findings with a recommended action. Reference specific work ` +
    `items by id (e.g. op-wp-42) in relatedNodeId. If your domain's data is not ` +
    `present in the portfolio (e.g. no cost, OKR, or readiness data), return an ` +
    `empty findings array — do not invent findings.\n\n` +
    `Respond with ONLY this JSON: {"findings":[{"title","severity":"low|medium|high",` +
    `"body","recommendation","relatedNodeId"}]} (max 5 findings).`
  );
}

/** Run one reasoning agent; returns the number of NEW findings recorded. */
export async function runReasoningAgent(agent: AgentDomain, context: string): Promise<number> {
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
  if (!parsed.success) return 0;

  let newCount = 0;
  for (const f of parsed.data.findings) {
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
    });
    if (!isNew) continue;
    newCount++;
    if (config.detectors.publish) {
      try {
        const alertWpId = await writeFinding({
          title: `${agent.name}: ${f.title}`,
          body: `${narrative}\n\nAgent: ${agent.id} · Finding: ${finding.id}`,
          severity: SEVERITY_TO_ALERT[f.severity],
          relatedWorkPackageId: wpId ? Number(wpId) : undefined,
        });
        await setFindingStatus(finding.id, 'published', { alertWpId });
      } catch (err: any) {
        console.warn(`[agent:${agent.id}] publish failed: ${err.message}`);
      }
    }
  }
  return newCount;
}

/** Run every reasoning agent (except Strategic PMO, handled by the project assessor). */
export async function runAgents(): Promise<number> {
  if (!config.reasoning.enabled) return 0;
  const context = await buildPortfolioContext();
  let total = 0;
  for (const agent of AGENT_ROSTER) {
    if (agent.id === 'strategic-pmo') continue;
    try {
      total += await runReasoningAgent(agent, context);
    } catch (err: any) {
      console.warn(`[agent:${agent.id}] reasoning failed: ${err.message}`);
    }
  }
  return total;
}
