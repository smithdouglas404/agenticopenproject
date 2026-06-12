/**
 * OpenProject inbound webhook route for the Kyndral-365 server.
 *
 * Registers POST /webhooks/openproject. On a verified event it does TWO things:
 *   1. data plane  — openProjectClient.handleWebhook(payload, sourceSystemId)
 *                    re-syncs the changed project into Kyndral storage/ontology;
 *   2. agent plane — emits an EventDrivenOrchestrator change event so only the
 *                    relevant agents fire (see server/patches/eventDrivenBootstrap.ts).
 *
 * Signature verification mirrors the proven implementation in
 * agentic-ppm/agent-runtime/src/webhook/server.ts (raw-body HMAC of the
 * X-OP-Signature header, crypto.timingSafeEqual, bare-hex tolerated, skip when
 * no secret is configured). OpenProject sends `sha1=<hex hmac-sha1>` by
 * default; we honor the algorithm named in the header prefix (sha1/sha256)
 * and default to SHA-1. Secret comes from OPENPROJECT_WEBHOOK_SECRET.
 *
 * ECHO GUARD: outbound writes (server/openProjectWriteback.ts) record each
 * pushed work-package id in a 30s-TTL set; work_package events for those ids
 * are skipped here via wasRecentlyPushed() so our own write-backs don't
 * re-sync (and re-trigger agents) as phantom inbound changes.
 *
 * DROP-IN (Kyndral server/index.ts or routes registry):
 *   import { initOpenProjectWebhook } from "./routes/webhooks/openproject";
 *   const opWebhooks = initOpenProjectWebhook(express.Router(), {
 *     client: new OpenProjectClient({ baseUrl, apiKey }),   // or from adapter
 *     orchestrator: eventDrivenOrchestrator,                // may be omitted
 *     sourceSystemId: "openproject",
 *   });
 *   app.use(opWebhooks);
 * Then configure the URL in OpenProject: Administration → Webhooks.
 */
import crypto from "node:crypto";
import express, { type Request, type Response, type Router } from "express";
import { wasRecentlyPushed } from "../../openProjectWriteback";

// ── Minimal structural types (Kyndral's real classes satisfy these) ─────────

/** Satisfied by server/openProjectClient.ts → OpenProjectClient. */
export interface OpenProjectWebhookClient {
  handleWebhook(payload: any, sourceSystemId: string): Promise<void>;
}

/**
 * Satisfied by server/lib/EventDrivenOrchestrator.ts. Declared structurally so
 * this file stays import-free of Kyndral internals; swap for
 * `import type { EventDrivenOrchestrator } from "../../lib/EventDrivenOrchestrator"`
 * once dropped into the Kyndral repo if you prefer the nominal type.
 */
export interface EventDrivenOrchestratorLike {
  registerChange(event: OrchestratorChangeEvent): unknown;
}

/** Shape accepted by EventDrivenOrchestrator.registerChange. */
export interface OrchestratorChangeEvent {
  /** Drives determineAgentsForEvents(): budget→finops+risk, schedule→tmo/pmo, risk→risk/governance, … */
  type: "budget" | "schedule" | "scope" | "status" | "risk" | string;
  projectId?: string;
  entityType?: string;
  entityId?: string;
  severity?: "low" | "medium" | "high" | "critical";
  source?: string;
  summary?: string;
  prev?: unknown;
  next?: unknown;
  timestamp?: string;
  [key: string]: unknown;
}

export interface OpenProjectWebhookDeps {
  client: OpenProjectWebhookClient;
  orchestrator?: EventDrivenOrchestratorLike;
  /** Integration/adapter id recorded as the sync source. Default "openproject". */
  sourceSystemId?: string;
  /** Override OPENPROJECT_WEBHOOK_SECRET (mostly for tests). */
  webhookSecret?: string;
}

interface OPWebhookEvent {
  action: string; // e.g. work_package:created, work_package:updated, project:updated
  work_package?: {
    id?: number;
    subject?: string;
    _links?: { project?: { href?: string }; status?: { title?: string } };
    [k: string]: unknown;
  };
  project?: { id?: number; name?: string; [k: string]: unknown };
}

// ── Signature verification (ported from agent-runtime/src/webhook/server.ts) ─

function verifySignature(
  rawBody: Buffer,
  signatureHeader: string | undefined,
  secret: string,
): boolean {
  if (!secret) return true; // no secret configured -> skip (dev only)
  if (!signatureHeader) return false;
  // OpenProject sends "sha1=<hex>" (some deployments: "sha256=<hex>");
  // tolerate a bare hex value too. Honor the algorithm in the prefix.
  const algo = signatureHeader.startsWith("sha256=") ? "sha256" : "sha1";
  const expected = `${algo}=` + crypto.createHmac(algo, secret).update(rawBody).digest("hex");
  const candidates = [expected, expected.replace(`${algo}=`, "")];
  return candidates.some((c) => {
    try {
      return crypto.timingSafeEqual(Buffer.from(signatureHeader), Buffer.from(c));
    } catch {
      return false; // length mismatch etc.
    }
  });
}

// ── Webhook action → orchestrator change event mapping ──────────────────────

function projectIdFromEvent(event: OPWebhookEvent): string | undefined {
  const href = event.work_package?._links?.project?.href;
  const fromWp = href?.split("/").pop();
  if (fromWp) return fromWp;
  if (event.project?.id != null) return String(event.project.id);
  return undefined;
}

function toChangeEvent(event: OPWebhookEvent): OrchestratorChangeEvent | null {
  const projectId = projectIdFromEvent(event);
  const base = {
    projectId,
    source: "openproject_webhook",
    timestamp: new Date().toISOString(),
  };
  switch (event.action) {
    case "work_package:created":
      // New work = scope change.
      return {
        ...base,
        type: "scope",
        entityType: "work_package",
        entityId: event.work_package?.id != null ? String(event.work_package.id) : undefined,
        severity: "medium",
        summary: `OpenProject WP created: ${event.work_package?.subject ?? "?"}`,
      };
    case "work_package:updated":
      // Updated work (status/dates/progress) = schedule-relevant change → tmo/pmo agents.
      return {
        ...base,
        type: "schedule",
        entityType: "work_package",
        entityId: event.work_package?.id != null ? String(event.work_package.id) : undefined,
        severity: "medium",
        summary: `OpenProject WP updated: ${event.work_package?.subject ?? "?"}`,
      };
    case "project:created":
    case "project:updated":
      return {
        ...base,
        type: "status",
        entityType: "project",
        entityId: projectId,
        severity: "low",
        summary: `OpenProject project ${event.action.split(":")[1]}: ${event.project?.name ?? projectId ?? "?"}`,
      };
    default:
      return null;
  }
}

// ── Router ───────────────────────────────────────────────────────────────────

/**
 * Wire the webhook endpoint onto a router with its dependencies and return it.
 * Mounts its own express.json({ verify }) so the raw body is available for the
 * HMAC check regardless of app-level body parsing order.
 */
export function initOpenProjectWebhook(router: Router, deps: OpenProjectWebhookDeps): Router {
  const secret = deps.webhookSecret ?? process.env.OPENPROJECT_WEBHOOK_SECRET ?? "";
  const sourceSystemId = deps.sourceSystemId ?? "openproject";

  router.post(
    "/webhooks/openproject",
    // Capture the raw body for HMAC verification while still parsing JSON.
    express.json({
      verify: (req, _res, buf) => {
        (req as Request & { rawBody?: Buffer }).rawBody = buf;
      },
    }),
    (req: Request, res: Response) => {
      const rawBody =
        (req as Request & { rawBody?: Buffer }).rawBody ?? Buffer.from(JSON.stringify(req.body));
      const signature = req.headers["x-op-signature"] as string | undefined;

      if (!verifySignature(rawBody, signature, secret)) {
        console.warn("[openproject-webhook] invalid signature");
        res.status(401).json({ error: "invalid signature" });
        return;
      }

      const event: OPWebhookEvent = req.body;
      if (!event?.action) {
        res.status(400).json({ error: "missing action field" });
        return;
      }

      // Echo guard: skip work_package events caused by our own outbound
      // write-back (openProjectWriteback marks each pushed id for 30s).
      const wpId = event.work_package?.id;
      if (event.action.startsWith("work_package") && wpId != null && wasRecentlyPushed(wpId)) {
        res.status(200).json({ received: true, action: event.action, skipped: "echo" });
        return;
      }

      // Acknowledge immediately, process in the background (OpenProject retries
      // on non-2xx; never make it wait on a sync + agent run).
      res.status(200).json({ received: true, action: event.action });

      void (async () => {
        // 1. Data plane: re-sync the affected project into Kyndral.
        await deps.client.handleWebhook(event, sourceSystemId);

        // 2. Agent plane: tell the event-driven orchestrator what changed so
        //    determineAgentsForEvents() can fire only the relevant agents.
        const change = toChangeEvent(event);
        if (change && deps.orchestrator) {
          deps.orchestrator.registerChange(change);
        }
      })().catch((err: any) => {
        console.error(`[openproject-webhook] error processing ${event.action}:`, err?.message ?? err);
      });
    },
  );

  return router;
}

export default initOpenProjectWebhook;
