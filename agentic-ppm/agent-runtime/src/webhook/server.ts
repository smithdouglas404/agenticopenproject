/**
 * OpenProject webhook receiver — Quick-slice pipeline entry point.
 *
 * ADAPTED from DOSv2 `server/routes/webhooks/openproject.ts`: HMAC-SHA256 verify of
 * the X-OP-Signature header, agent-origin dedup, ack-immediately-then-process-async.
 * The downstream is re-pointed: instead of syncing to Palantir + broadcasting to a UI,
 * it runs  projector -> Insights & Risk agent -> inbox.
 *
 *   POST /webhooks/openproject  <- configure this URL in the OpenProject webhook admin
 */
import crypto from 'node:crypto';
import express, { type Express, type Request, type Response } from 'express';
import { config } from '../config.js';
import { getProjector } from '../projector/projector.js';
import { getOpenProjectClient } from '../openproject/client.js';
import { runInsightsAndRisk } from '../agents/insightsRiskAgent.js';
import { publishInsight } from '../inbox/inbox.js';

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
  work_package?: { id?: number; subject?: string; _links?: { project?: { href?: string } }; [k: string]: unknown };
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
  // Also skip anything inside the alerts project (our own Agent Alerts), so the
  // loop never feeds on itself even when custom fields aren't configured.
  if (await isInAlertsProject(event)) {
    console.log('[webhook] skipping event inside the alerts project');
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

      // 2. Re-run the Insights & Risk agent for the owning project.
      // TODO(debounce): coalesce bursts of WP updates per project before re-running.
      const projectNodeId = projectNodeIdFromEvent(event);
      if (!projectNodeId) {
        console.warn(`[webhook] WP ${wpId} has no resolvable project; skipping analysis`);
        return;
      }

      const insight = await runInsightsAndRisk(projectNodeId);
      if (!insight) return;

      // 3. Publish findings to the Insights inbox.
      const ids = await publishInsight(insight);
      console.log(`[webhook] published ${ids.length} finding(s) for ${projectNodeId}: [${ids.join(', ')}]`);
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
