/**
 * Approved-action executor — the advisory -> action leap, HITL-gated.
 *
 * When a human APPROVES a finding in the console, the agent doesn't just note
 * it: it creates a concrete follow-up task in the project that owns the related
 * work item, so the recommendation lands in the team's actual backlog. Every
 * action is traceable (the follow-up references the finding id and the related
 * WP gets a comment).
 *
 * Deliberately conservative for now: one action kind (create_followup_task),
 * only when the finding points at a concrete work package, and only when
 * AGENT_ACTIONS=1 (default). Findings without a target (e.g. CapacityOverload
 * per-assignee) stay comment-only until richer actions are defined.
 */
import { getOpenProjectClient } from '../openproject/client.js';
import { config } from '../config.js';
import type { StoredFinding } from '../store/findings.js';

export interface ActionResult {
  kind: 'create_followup_task';
  followupWpId: number;
  detail: string;
}

export async function executeApprovedAction(finding: StoredFinding): Promise<ActionResult | null> {
  if (!config.actions.enabled) return null;
  if (!finding.workPackageId) return null; // no concrete target -> comment-only

  const client = getOpenProjectClient();

  // The follow-up belongs in the project that owns the related work package.
  const related = await client.getWorkPackage(finding.workPackageId);
  const projectId = related._links?.project?.href?.split('/').pop();
  if (!projectId) return null;

  const typeHref = await client.getTypeHref(config.actions.followupType);
  const payload: Record<string, unknown> = {
    subject: `[Agent follow-up] ${finding.title}`.slice(0, 255),
    description: {
      raw:
        `${finding.body}\n\n---\n` +
        `Raised by **${finding.agentId}** (finding \`${finding.id}\`), approved via the Agent Console.\n` +
        `Relates to work package #${finding.workPackageId}.`,
    },
  };
  if (typeHref) payload._links = { type: { href: typeHref } };

  const created = await client.createWorkPackage(
    projectId,
    payload as Parameters<typeof client.createWorkPackage>[1],
  );

  await client
    .addWorkPackageComment(
      finding.workPackageId,
      `🤖 Follow-up task **#${created.id}** created after human approval of: ${finding.title}`,
    )
    .catch(() => {});

  return {
    kind: 'create_followup_task',
    followupWpId: created.id!,
    detail: `Created follow-up WP #${created.id} in project ${projectId}`,
  };
}
