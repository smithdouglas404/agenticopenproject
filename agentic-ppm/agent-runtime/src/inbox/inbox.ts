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

export type AlertSeverity = 'notification' | 'warning' | 'alarm' | 'critical';

export interface InboxFinding {
  title: string;
  body: string;
  severity: AlertSeverity;
  relatedWorkPackageId?: number;
}

/** Write a single finding as an Agent Alert work package. Returns the created WP id. */
export async function writeFinding(finding: InboxFinding): Promise<number> {
  const client = getOpenProjectClient();

  // Build a payload that works on a stock OpenProject: a valid type, and custom
  // fields only when their API keys are configured (otherwise we'd 422).
  const payload: Record<string, unknown> = {
    subject: `[${finding.severity.toUpperCase()}] ${finding.title}`,
    description: { raw: `${finding.body}\n\n_— ${config.openproject.syncSource}_` },
  };

  const typeHref = await client.getTypeHref(config.openproject.alertType);
  if (typeHref) payload._links = { type: { href: typeHref } };

  const cfSource = config.openproject.customFieldSyncSource;
  if (cfSource) payload[cfSource] = config.openproject.syncSource;
  const cfSeverity = config.openproject.customFieldAlertSeverity;
  if (cfSeverity) payload[cfSeverity] = finding.severity;

  const wp = await client.createWorkPackage(
    config.openproject.alertsProject,
    payload as Parameters<typeof client.createWorkPackage>[1],
  );

  if (finding.relatedWorkPackageId) {
    await client.addWorkPackageComment(
      finding.relatedWorkPackageId,
      `**Agent Alert (${finding.severity}):** ${finding.title}\n\n${finding.body}`,
    );
  }

  return wp.id!;
}

/** Publish detector findings (from agents/detectors.ts) as Agent Alerts. */
export async function publishDetectorFindings(
  findings: { type: string; severity: 'low' | 'medium' | 'high'; title: string; body: string; workPackageId?: number }[],
): Promise<number[]> {
  const severityMap: Record<'low' | 'medium' | 'high', AlertSeverity> = {
    low: 'notification',
    medium: 'warning',
    high: 'alarm',
  };
  const ids: number[] = [];
  for (const f of findings) {
    ids.push(
      await writeFinding({
        title: `${f.type}: ${f.title}`,
        body: f.body,
        severity: severityMap[f.severity],
        relatedWorkPackageId: f.workPackageId,
      }),
    );
  }
  return ids;
}
