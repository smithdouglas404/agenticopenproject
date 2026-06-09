/**
 * Insights inbox writer.
 *
 * ADAPTED from DOSv2 `opSendNotificationTool` (server/agents/tools/OpenProjectAgentTools.ts):
 * findings are written back to OpenProject as "Agent Alert" work packages, tagged with a
 * sync_source marker so the webhook handler ignores the echo. The finding fields mirror the
 * `Intervention` shape from server/reactiveMetricWatcher.ts.
 *
 * This is the Quick-slice inbox surface. The richer in-app inbox view lives in the Rails
 * engine `modules/agentic_ppm` (reuse map gap #3) and can read these same WPs.
 */
import { getOpenProjectClient } from '../openproject/client.js';
import { config } from '../config.js';
import type { Insight } from '../agents/insightSchema.js';

export type AlertSeverity = 'notification' | 'warning' | 'alarm' | 'critical';

const RISK_SEVERITY_TO_ALERT: Record<'high' | 'medium' | 'low', AlertSeverity> = {
  high: 'alarm',
  medium: 'warning',
  low: 'notification',
};

export interface InboxFinding {
  title: string;
  body: string;
  severity: AlertSeverity;
  relatedWorkPackageId?: number;
}

/** Write a single finding as an Agent Alert work package. Returns the created WP id. */
export async function writeFinding(finding: InboxFinding): Promise<number> {
  const client = getOpenProjectClient();
  const wp = await client.createWorkPackage(config.openproject.alertsProject, {
    subject: `[${finding.severity.toUpperCase()}] ${finding.title}`,
    description: { raw: finding.body },
    customField_sync_source: config.openproject.syncSource,
    customField_alert_severity: finding.severity,
  });

  if (finding.relatedWorkPackageId) {
    await client.addWorkPackageComment(
      finding.relatedWorkPackageId,
      `**Agent Alert (${finding.severity}):** ${finding.title}\n\n${finding.body}`,
    );
  }

  return wp.id!;
}

/** Extract the trailing numeric id from a graph node id like "op-wp-1234". */
function workPackageIdFromRef(ref?: string): number | undefined {
  if (!ref) return undefined;
  const match = ref.match(/op-wp-(\d+)/);
  return match ? Number(match[1]) : undefined;
}

/**
 * Fan an Insight out into inbox findings: one summary alert plus one per key risk.
 * Returns the ids of the created Agent Alert work packages.
 */
export async function publishInsight(insight: Insight): Promise<number[]> {
  const created: number[] = [];

  const summarySeverity: AlertSeverity =
    insight.portfolioHealth === 'red' ? 'critical' : insight.portfolioHealth === 'amber' ? 'warning' : 'notification';

  const summaryBody = [
    insight.healthSummary,
    '',
    insight.recommendations.map((r) => `- (${r.priority}) ${r.action} — ${r.rationale}`).join('\n'),
  ].join('\n');

  created.push(
    await writeFinding({ title: insight.headline, body: summaryBody, severity: summarySeverity }),
  );

  for (const risk of insight.keyRisks) {
    created.push(
      await writeFinding({
        title: risk.title,
        body: `**Impact:** ${risk.impact}\n\n**Mitigation:** ${risk.mitigation}`,
        severity: RISK_SEVERITY_TO_ALERT[risk.severity],
        relatedWorkPackageId: workPackageIdFromRef(risk.linkedEntity),
      }),
    );
  }

  return created;
}
