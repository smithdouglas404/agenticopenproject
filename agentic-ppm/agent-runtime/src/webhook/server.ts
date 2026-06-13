/**
 * OpenProject webhook receiver — grounding-service pipeline entry point.
 *
 * ADAPTED from DOSv2 `server/routes/webhooks/openproject.ts`: HMAC-SHA256 verify of
 * the X-OP-Signature header, agent-origin dedup, ack-immediately-then-process-async.
 * The downstream is the deterministic grounding layer: projector (graph write) ->
 * rules evaluation (changed nodes) -> detector sweep trigger -> inbox. No LLM.
 *
 *   POST /webhooks/openproject  <- configure this URL in the OpenProject webhook admin
 */
import crypto from 'node:crypto';
import express, { type Express, type Request, type Response } from 'express';
import { config } from '../config.js';
import { getProjector } from '../projector/projector.js';
import { getOpenProjectClient } from '../openproject/client.js';
import { getFindingByAlertWp } from '../store/findings.js';
import { decideFinding } from '../agents/decisions.js';
import { maybeSweepAfterEvent } from '../agents/sweep.js';
import { evaluateForChangedNodes, publishBreaches } from '../rules/evaluator.js';
import { buildConsoleRouter } from '../console/api.js';

// Resolve the alerts project's numeric id once, so we can ignore our own Agent
// Alerts (which live in that project) without depending on a custom field.
let alertsProjectId: string | null = null;
async function isInAlertsProject(event: OPWebhookEvent): Promise<boolean> {
  if (alertsProjectId === null) {
    try {
      const p = await getOpenProjectClient().getProject(config.openproject.alertsProject);
      alertsProjectId = String((p as { id?: number | string }).id ?? '');
    } catch {
      alertsProjectId = '';
    }
  }
  if (!alertsProjectId) return false;
  const wpProj = event.work_package?._links?.project?.href?.split('/').pop();
  const projId = event.project?.id != null ? String(event.project.id) : undefined;
  return wpProj === alertsProjectId || projId === alertsProjectId;
}

interface OPWebhookEvent {
  action: string; // e.g. work_package:created, work_package:updated, project:updated
  work_package?: {
    id?: number;
    subject?: string;
    _links?: { project?: { href?: string }; status?: { title?: string } };
    [k: string]: unknown;
  };
  project?: { id?: number; name?: string };
}

function verifySignature(rawBody: Buffer, signatureHeader: string | undefined, secret: string): boolean {
  if (!secret) return true; // no secret configured -> skip (dev only)
  if (!signatureHeader) return false;
  const expected = 'sha256=' + crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
  // OpenProject sends "sha256=<hex>"; tolerate a bare hex value too.
  const candidates = [expected, expected.replace('sha256=', '')];
  return candidates.some((c) => {
    try {
      return crypto.timingSafeEqual(Buffer.from(signatureHeader), Buffer.from(c));
    } catch {
      return false;
    }
  });
}

function projectNodeIdFromEvent(event: OPWebhookEvent): string | null {
  const href = event.work_package?._links?.project?.href;
  if (href) {
    const id = href.split('/').pop();
    if (id) return `op-project-${id}`;
  }
  if (event.project?.id) return `op-project-${event.project.id}`;
  return null;
}

// Map an Agent Alert WP status to a HITL decision. Closed/Resolved = approve
// (the human accepted the recommendation); Rejected = reject. Configurable names.
const APPROVE_STATUSES = (process.env.ALERT_APPROVE_STATUSES ?? 'closed,resolved,approved,done')
  .split(',').map((s) => s.trim().toLowerCase());
const REJECT_STATUSES = (process.env.ALERT_REJECT_STATUSES ?? 'rejected,cancelled,canceled')
  .split(',').map((s) => s.trim().toLowerCase());

async function handleAlertStatusChange(alertWpId: number, statusTitle?: string): Promise<void> {
  if (!statusTitle) return;
  const s = statusTitle.toLowerCase();
  const decision = APPROVE_STATUSES.includes(s) ? 'approved' : REJECT_STATUSES.includes(s) ? 'rejected' : null;
  if (!decision) return;

  const finding = await getFindingByAlertWp(alertWpId);
  if (!finding) return;
  const r = await decideFinding(finding.id, decision, `openproject:${statusTitle}`);
  if (r.ok) console.log(`[webhook] alert WP ${alertWpId} -> finding ${finding.id} ${decision} via OpenProject status`);
}

async function processEvent(event: OPWebhookEvent): Promise<void> {
  const { action } = event;
  console.log(
    `[webhook] received ${action}` +
      (event.work_package?.id ? ` wp=${event.work_package.id}` : '') +
      (event.project?.id ? ` project=${event.project.id}` : ''),
  );

  // Dedup: ignore changes our own agent made.
  const syncSource = event.work_package?.['customField_sync_source'];
  if (syncSource === config.openproject.syncSource) {
    console.log(`[webhook] skipping agent-originated event for WP ${event.work_package?.id}`);
    return;
  }
  // Events inside the alerts project are our own Agent Alerts. We don't re-project
  // them — BUT a human changing an alert's STATUS is an approve/reject decision,
  // making OpenProject a first-class HITL surface equal to the console.
  if (await isInAlertsProject(event)) {
    if (event.action === 'work_package:updated' && event.work_package?.id) {
      await handleAlertStatusChange(event.work_package.id, event.work_package._links?.status?.title);
    }
    return;
  }

  const projector = getProjector();

  switch (action) {
    case 'work_package:created':
    case 'work_package:updated': {
      const wpId = event.work_package?.id;
      if (!wpId) return;

      // 1. Project the change into the graph.
      const projected = await projector.syncSingleWorkPackage(wpId);
      console.log(
        projected
          ? `[webhook] projected WP ${wpId} as ${projected.label} (${projected.nodeId})`
          : `[webhook] WP ${wpId} skipped (agent-originated)`,
      );

      // 2. Resolve the owning project for targeted rule evaluation.
      const projectNodeId = projectNodeIdFromEvent(event);
      if (!projectNodeId) {
        console.warn(`[webhook] WP ${wpId} has no resolvable project; skipping analysis`);
        return;
      }

      // 3. Run the deterministic detectors opportunistically (throttled).
      maybeSweepAfterEvent();

      // 4. Event-targeted rule evaluation: evaluate rules only against the nodes
      //    this event touched (the changed WP + its owning project), so a breach
      //    surfaces immediately without waiting for the throttled full sweep.
      if (config.rules.enabled && config.rules.evaluateOnEvent) {
        const changedIds = [projected?.nodeId, projectNodeId].filter(
          (id): id is string => typeof id === 'string',
        );
        void evaluateForChangedNodes(changedIds)
          .then((breaches) => publishBreaches(breaches))
          .catch((err) => console.warn(`[webhook] rule evaluation failed: ${err.message}`));
      }
      break;
    }

    case 'project:created':
    case 'project:updated': {
      if (event.project) {
        await projector.syncProject(event.project as any);
        console.log(`[webhook] projected project ${event.project.name ?? event.project.id}`);
      }
      break;
    }

    default:
      console.log(`[webhook] unhandled action: ${action}`);
  }
}

export function buildApp(): Express {
  const app = express();
  // Capture the raw body for HMAC verification while still parsing JSON.
  app.use(
    express.json({
      verify: (req, _res, buf) => {
        (req as Request & { rawBody?: Buffer }).rawBody = buf;
      },
    }),
  );

  app.get('/health', (_req: Request, res: Response) => {
    res.json({ status: 'ok', service: 'agentic-ppm-agent-runtime' });
  });

  // HITL Agent Console (UI + API).
  app.use(buildConsoleRouter());

  app.post('/webhooks/openproject', (req: Request, res: Response) => {
    const rawBody = (req as Request & { rawBody?: Buffer }).rawBody ?? Buffer.from(JSON.stringify(req.body));
    const signature = req.headers['x-op-signature'] as string | undefined;

    if (!verifySignature(rawBody, signature, config.openproject.webhookSecret)) {
      console.warn('[webhook] invalid signature');
      return res.status(401).json({ error: 'invalid signature' });
    }

    const event: OPWebhookEvent = req.body;
    if (!event?.action) {
      return res.status(400).json({ error: 'missing action field' });
    }

    // Acknowledge immediately, process in the background.
    res.status(200).json({ received: true, action: event.action });

    void processEvent(event).catch((err) => {
      console.error(`[webhook] error processing ${event.action}:`, err.message);
    });
  });

  return app;
}
