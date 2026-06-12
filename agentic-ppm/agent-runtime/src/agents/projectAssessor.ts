/**
 * Project assessor — runs the Strategic PMO insight for a project and writes the
 * verdict to (a) the OpenProject Project Status banner and (b) a portfolio-insight
 * finding for the console. Shared by the webhook (on edit) and the sweep (on a
 * schedule), so project status refreshes predictably, not only on manual edits.
 */
import { runInsightsAndRisk } from './insightsRiskAgent.js';
import { publishInsight } from '../inbox/inbox.js';
import { recordFinding, setFindingStatus } from '../store/findings.js';
import { getOpenProjectClient } from '../openproject/client.js';
import { getGraph } from '../graph/falkor.js';
import { config } from '../config.js';

const HEALTH_TO_STATUS: Record<string, 'on_track' | 'at_risk' | 'off_track'> = {
  green: 'on_track',
  amber: 'at_risk',
  red: 'off_track',
};

/** UTC timestamp to the minute, e.g. "2026-06-12 14:30 UTC". */
function stamp(): string {
  return `${new Date().toISOString().slice(0, 16).replace('T', ' ')} UTC`;
}

/** Assess one project; returns true if an insight was produced. */
export async function assessProject(projectNodeId: string): Promise<boolean> {
  const insight = await runInsightsAndRisk(projectNodeId);
  if (!insight) return false;

  const ids = await publishInsight(insight);

  const opProjectId = projectNodeId.replace(/^op-project-/, '');
  const isProject = !!opProjectId && opProjectId !== projectNodeId;
  const topRec = insight.recommendations[0];
  const narrative =
    `${insight.healthSummary}` + (topRec ? `\n\n**Next:** ${topRec.action} — ${topRec.rationale}` : '');

  if (config.actions.setProjectStatus && isProject) {
    const statusCode = HEALTH_TO_STATUS[insight.portfolioHealth] ?? 'at_risk';
    const explanation =
      `**${insight.headline}**\n\n${narrative}\n\n_Assessed by the Strategic PMO agent · ${stamp()}_`;
    await getOpenProjectClient()
      .updateProjectStatus(opProjectId, statusCode, explanation)
      .then(() => console.log(`[assess] project ${opProjectId} status = ${statusCode} @ ${stamp()}`))
      .catch((err) => console.warn(`[assess] set project status failed: ${err.message}`));
  }

  const { finding } = await recordFinding({
    type: 'portfolio-insight',
    agentId: 'strategic-pmo',
    severity: insight.portfolioHealth === 'red' ? 'high' : insight.portfolioHealth === 'amber' ? 'medium' : 'low',
    title: insight.headline,
    body: insight.healthSummary,
    narrative,
    nodeId: projectNodeId,
    projectId: isProject ? Number(opProjectId) : undefined,
  });
  // portfolio-insight is a living assessment: re-publish so the console shows it as current.
  await setFindingStatus(finding.id, 'published', ids[0] ? { alertWpId: ids[0] } : undefined);
  return true;
}

/** Re-assess every project in the graph (used by the sweep). Sequential + capped. */
export async function assessAllProjects(max = 25): Promise<number> {
  const rows = await getGraph().query<{ id: string }>('MATCH (p:Project) RETURN p.id AS id LIMIT ' + max);
  let n = 0;
  for (const r of rows) {
    try {
      if (await assessProject(r.id)) n++;
    } catch (err: any) {
      console.warn(`[assess] ${r.id} failed: ${err.message}`);
    }
  }
  return n;
}
