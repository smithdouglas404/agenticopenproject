/**
 * Portfolio Insights & Risk agent (Quick slice).
 *
 * COMPOSED, per the reuse map (doc 09 §3c), from three DOSv2 pieces:
 *   1. the `risk` agent persona (server/mastra/index.ts) — instructions below,
 *   2. the deterministic risk math (server/agents/deep/DeepRiskAgent.ts) — riskHeuristics.ts,
 *   3. the insight finding shape + prompt (server/executiveInsights.ts) — insightSchema.ts.
 *
 * Re-pointed off Drizzle `storage` onto the FalkorDB graph, and off OpenRouter onto
 * the Claude API. For the Quick slice this is a direct Messages call rather than a
 * Mastra tool-loop; the full Mastra runtime + A2A is a later lift (doc 09 §2 KEEP).
 */
import { getGraph } from '../graph/falkor.js';
import { callLLMJson } from '../llm/claude.js';
import { lettaConfigured, getRosterAgentId, sendToAgent } from '../letta/client.js';
import { InsightSchema, type Insight } from './insightSchema.js';
import {
  analyzeRiskProbability,
  calculateRiskImpact,
  type RiskInput,
} from './riskHeuristics.js';

const SYSTEM_PROMPT = `You are the Portfolio Insights & Risk Agent for a project portfolio managed in OpenProject.

Your role is to provide portfolio-level insights that are:
1. ACTIONABLE - every insight leads to a clear decision or action
2. QUANTIFIED - include specific numbers, percentages, and dates
3. EVIDENCE-BASED - reference specific work packages or projects by name/id from the data
4. PRIORITIZED - surface the highest-probability, highest-impact risks first

You are given pre-computed risk probability and impact scores. Reason over those scores;
do not invent new ones. Respond in valid JSON only, with no text outside the JSON object.`;

interface GraphWorkItem {
  id: string;
  name: string;
  status?: string;
  priority?: string;
  progress?: number;
  startDate?: string;
  endDate?: string;
}

/**
 * Pull the work items belonging to a project from the graph.
 * Cypher shape ports from DOSv2 GraphService; FalkorDB is openCypher-compatible.
 */
async function loadProjectItems(projectNodeId: string): Promise<GraphWorkItem[]> {
  const graph = getGraph();
  const rows = await graph.query<{ item: { properties: GraphWorkItem } }>(
    `MATCH (p:Project { id: $projectId })-[:CONTAINS]->(item)
     RETURN item
     LIMIT 200`,
    { projectId: projectNodeId },
  );
  // FalkorDB returns node objects; normalize to their properties.
  return rows
    .map((r) => (r.item as any)?.properties ?? r.item)
    .filter((x): x is GraphWorkItem => !!x && typeof x.id === 'string');
}

/** Build the scored evidence block the LLM reasons over. */
function buildContext(projectNodeId: string, items: GraphWorkItem[]): string {
  const scored = items.map((item) => {
    const input: RiskInput = {
      id: item.id,
      name: item.name,
      status: item.status,
      priority: item.priority,
      progress: item.progress,
      startDate: item.startDate,
      endDate: item.endDate,
    };
    const probability = analyzeRiskProbability(input);
    const impact = calculateRiskImpact(input, 'schedule_delay', severityFromProbability(probability.level));
    return { item, probability, impact };
  });

  // Highest exposure first.
  scored.sort((a, b) => b.probability.score * b.impact.overallScore - a.probability.score * a.impact.overallScore);

  const lines = scored
    .slice(0, 25)
    .map(
      ({ item, probability, impact }) =>
        `- ${item.name} (${item.id}) | status=${item.status ?? 'n/a'} priority=${item.priority ?? 'n/a'} progress=${item.progress ?? 0}% ` +
        `| riskProbability=${probability.score}% (${probability.level}) impact=${Math.round(impact.overallScore)} (${impact.level})` +
        (probability.factors.length ? ` | factors: ${probability.factors.join('; ')}` : ''),
    );

  return `PROJECT: ${projectNodeId}\nWORK ITEMS (${items.length} total, top by risk exposure):\n${lines.join('\n')}`;
}

function severityFromProbability(level: 'high' | 'medium' | 'low') {
  return level === 'high' ? 'major' : level === 'medium' ? 'moderate' : 'minor';
}

const USER_PROMPT_TEMPLATE = (context: string) => `Based on this portfolio data, generate an insight report.

${context}

Return JSON with exactly this structure:
{
  "headline": "One impactful sentence summarizing portfolio state",
  "portfolioHealth": "green" | "amber" | "red",
  "healthSummary": "2-3 sentence explanation of overall health",
  "keyRisks": [{ "title": "...", "impact": "quantified impact", "mitigation": "action", "severity": "high"|"medium"|"low", "linkedEntity": "work item id or name" }],
  "opportunities": [{ "title": "...", "potentialValue": "quantified", "action": "...", "linkedEntity": "..." }],
  "recommendations": [{ "action": "...", "rationale": "...", "priority": "urgent"|"high"|"medium", "actionRef": "op-wp-<id>" }],
  "kpiHighlights": [{ "name": "...", "status": "on-track"|"at-risk"|"off-track", "delta": "+5% vs target" }]
}

Provide up to 3 key risks (highest exposure first), up to 3 recommendations, and up to 4 KPI highlights.`;

/** Pull the first balanced JSON object out of a (possibly chatty) agent reply. */
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

/**
 * Reason THROUGH the Strategic PMO Letta agent (stateful, memory-aware). Returns
 * a validated Insight, or null to fall back to the direct Claude path.
 */
async function reasonThroughLetta(context: string): Promise<Insight | null> {
  const agentId = await getRosterAgentId('strategic-pmo');
  if (!agentId) return null;
  const reply = await sendToAgent(
    agentId,
    USER_PROMPT_TEMPLATE(context) + '\n\nRespond with ONLY the JSON object, no prose.',
  );
  if (!reply) return null;
  const raw = extractJson(reply);
  if (!raw) return null;
  const parsed = InsightSchema.safeParse(raw);
  return parsed.success ? { ...parsed.data, generatedAt: new Date().toISOString() } : null;
}

/**
 * Run the agent for one project node and return a validated Insight.
 * Returns null if the project has no work items to reason about.
 *
 * When Letta is configured, the reasoning runs through the stateful Strategic PMO
 * agent (so it remembers prior assessments); otherwise it uses a direct Claude call.
 */
export async function runInsightsAndRisk(projectNodeId: string): Promise<Insight | null> {
  const items = await loadProjectItems(projectNodeId);
  if (items.length === 0) return null;

  const context = buildContext(projectNodeId, items);

  if (lettaConfigured()) {
    const viaLetta = await reasonThroughLetta(context).catch((err) => {
      console.warn(`[insights] Letta reasoning failed, falling back to Claude-direct: ${err.message}`);
      return null;
    });
    if (viaLetta) {
      console.log('[insights] reasoned via Letta agent (strategic-pmo)');
      return viaLetta;
    }
  }

  // Direct Claude path (default, and the fallback when Letta is unavailable).
  const raw = await callLLMJson(SYSTEM_PROMPT, USER_PROMPT_TEMPLATE(context), { maxTokens: 2000 });
  const parsed = InsightSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error(`Insight validation failed: ${parsed.error.message}`);
  }
  return { ...parsed.data, generatedAt: new Date().toISOString() };
}
