/**
 * Finding decisions — the shared approve/reject logic used by BOTH the Agent
 * Console (/api/findings/:id/approve) and the OpenProject-native HITL (changing
 * an Agent Alert work package's status). Whichever surface a human uses, the
 * same thing happens, so the console and OpenProject are true equivalents.
 *
 * Approve -> execute the gated action (create follow-up task) + comment back.
 * Reject  -> mark rejected + comment back.
 * Idempotent: a finding already approved/rejected is a no-op (so status-change
 * echoes from OpenProject can't double-fire).
 */
import { getFinding, setFindingStatus, type StoredFinding } from '../store/findings.js';
import { executeApprovedAction, type ActionResult } from './actions.js';
import { recordHumanDecision } from '../learning/outcomes.js';
import { getOpenProjectClient } from '../openproject/client.js';

export interface DecisionResult {
  ok: boolean;
  code: number;
  finding?: StoredFinding;
  action?: ActionResult | null;
  error?: string;
}

export async function decideFinding(
  id: string,
  decision: 'approved' | 'rejected',
  decidedBy: string,
): Promise<DecisionResult> {
  const finding = await getFinding(id);
  if (!finding) return { ok: false, code: 404, error: 'finding not found' };
  if (finding.status === 'approved' || finding.status === 'rejected') {
    return { ok: true, code: 200, finding }; // idempotent no-op
  }

  // On approval, execute the concrete action (HITL-gated; see agents/actions.ts).
  let action: ActionResult | null = null;
  if (decision === 'approved') {
    action = await executeApprovedAction(finding).catch((err) => {
      console.warn(`[decision] approved action failed for ${finding.id}: ${err.message}`);
      return null;
    });
  }

  const updated = await setFindingStatus(finding.id, decision, {
    decidedBy,
    followupWpId: action?.followupWpId,
  });

  // LEARNING: the human decision is the most reliable outcome label we have —
  // resolve the matching prediction immediately (approved = confirmed, rejected
  // = negative signal), whichever HITL surface (console or OpenProject) decided.
  await recordHumanDecision(finding, decision);

  // Reflect the decision back into OpenProject so both surfaces stay in sync.
  const client = getOpenProjectClient();
  const note =
    decision === 'approved'
      ? `✅ **Approved** by ${decidedBy}.` + (action ? ` ${action.detail}.` : ` Action: ${finding.title}`)
      : `❌ **Rejected** by ${decidedBy}. No action will be taken.`;
  if (finding.alertWpId) {
    await client.addWorkPackageComment(finding.alertWpId, note).catch(() => {});
  }
  if (decision === 'approved' && finding.workPackageId && !action) {
    await client
      .addWorkPackageComment(
        finding.workPackageId,
        `**Agent recommendation approved:** ${finding.title}\n\n${finding.body}`,
      )
      .catch(() => {});
  }

  console.log(`[decision] ${finding.id} ${decision} by ${decidedBy}` + (action ? ` — ${action.detail}` : ''));
  return { ok: true, code: 200, finding: updated ?? finding, action };
}
