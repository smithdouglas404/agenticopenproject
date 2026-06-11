/**
 * Agent Console API — the HITL backend (Phase 2).
 *
 * GET  /console                      the console UI
 * GET  /api/roster                   agents + open/total finding counts
 * GET  /api/findings?status=&agent=  findings ("open" = new|published)
 * POST /api/findings/:id/approve     human approves -> comment on alert WP
 * POST /api/findings/:id/reject      human rejects  -> comment on alert WP
 * POST /api/sweep                    run the detector sweep on demand
 *
 * If CONSOLE_TOKEN is set, all of the above require Bearer auth (or ?token=).
 * Decisions are auditable: status + decidedBy land on the AgentFinding node, and
 * a comment is posted on the corresponding Agent Alert WP in OpenProject.
 */
import { Router, type Request, type Response, type NextFunction } from 'express';
import { AGENT_ROSTER } from '../agents/roster.js';
import { listFindings, getFinding, setFindingStatus, findingCountsByAgent, type FindingStatus } from '../store/findings.js';
import { getOpenProjectClient } from '../openproject/client.js';
import { executeApprovedAction } from '../agents/actions.js';
import { runSweep } from '../agents/sweep.js';
import { config } from '../config.js';
import { CONSOLE_HTML } from './page.js';

function auth(req: Request, res: Response, next: NextFunction): void {
  const token = config.console.token;
  if (!token) return next(); // private-network deployment; no token configured
  const presented =
    (req.headers.authorization ?? '').replace(/^Bearer\s+/i, '') ||
    String(req.query.token ?? '');
  if (presented === token) return next();
  res.status(401).json({ error: 'unauthorized' });
}

async function decide(req: Request, res: Response, decision: 'approved' | 'rejected'): Promise<void> {
  const finding = await getFinding(req.params.id);
  if (!finding) {
    res.status(404).json({ error: 'finding not found' });
    return;
  }
  if (finding.status === 'approved' || finding.status === 'rejected') {
    res.status(409).json({ error: `already ${finding.status}` });
    return;
  }

  const decidedBy = String(req.body?.decidedBy ?? 'console');

  // On approval, execute the concrete action (HITL-gated; see agents/actions.ts).
  let action: Awaited<ReturnType<typeof executeApprovedAction>> = null;
  if (decision === 'approved') {
    action = await executeApprovedAction(finding).catch((err) => {
      console.warn(`[console] approved action failed for ${finding.id}: ${err.message}`);
      return null;
    });
  }

  const updated = await setFindingStatus(finding.id, decision, {
    decidedBy,
    followupWpId: action?.followupWpId,
  });

  // Reflect the decision into OpenProject so the WP record matches the console.
  const note =
    decision === 'approved'
      ? `✅ **Approved** via Agent Console by ${decidedBy}.` +
        (action ? ` ${action.detail}.` : ` The team should action: ${finding.title}`)
      : `❌ **Rejected** via Agent Console by ${decidedBy}. No action will be taken.`;
  if (finding.alertWpId) {
    await getOpenProjectClient()
      .addWorkPackageComment(finding.alertWpId, note)
      .catch((err) => console.warn(`[console] comment on alert WP failed: ${err.message}`));
  }
  if (decision === 'approved' && finding.workPackageId && !action) {
    await getOpenProjectClient()
      .addWorkPackageComment(
        finding.workPackageId,
        `**Agent recommendation approved:** ${finding.title}\n\n${finding.body}`,
      )
      .catch(() => {});
  }

  console.log(`[console] finding ${finding.id} ${decision} by ${decidedBy}` + (action ? ` — ${action.detail}` : ''));
  res.json({ ...updated, action });
}

export function buildConsoleRouter(): Router {
  const router = Router();
  router.use(['/console', '/api'], auth);

  router.get('/console', (_req, res) => {
    res.type('html').send(CONSOLE_HTML);
  });

  router.get('/api/roster', async (_req, res) => {
    const counts = await findingCountsByAgent().catch(() => ({}) as Record<string, { open: number; total: number }>);
    res.json(AGENT_ROSTER.map((a) => ({ ...a, counts: counts[a.id] ?? { open: 0, total: 0 } })));
  });

  router.get('/api/findings', async (req, res) => {
    const status = String(req.query.status ?? '');
    const agentId = req.query.agent ? String(req.query.agent) : undefined;
    if (status === 'open' || status === '') {
      const [fresh, published] = await Promise.all([
        listFindings({ status: 'new', agentId }),
        listFindings({ status: 'published', agentId }),
      ]);
      const merged = [...fresh, ...published].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
      res.json(status === '' ? await listFindings({ agentId }) : merged);
      return;
    }
    res.json(await listFindings({ status: status as FindingStatus, agentId }));
  });

  router.post('/api/findings/:id/approve', (req, res) => void decide(req, res, 'approved'));
  router.post('/api/findings/:id/reject', (req, res) => void decide(req, res, 'rejected'));

  router.post('/api/sweep', async (_req, res) => {
    res.json(await runSweep('manual'));
  });

  return router;
}
