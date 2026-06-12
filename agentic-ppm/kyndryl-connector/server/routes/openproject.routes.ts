/**
 * OpenProject outbound-sync routes for the Kyndral-365 server.
 *
 * The HTTP surface for server/openProjectWriteback.ts — what the Kyndral UI
 * calls when a user edits a SYNCED entity, so the change lands back in
 * OpenProject (the system of record):
 *
 *   PATCH /api/openproject/entities/:entityType/:externalId
 *         body = KyndralEntityChanges (zod-validated partial: name,
 *         description, status, priority, assigneeName, startDate, dueDate,
 *         percentComplete). entityType "project" routes to pushProjectUpdate
 *         (project PATCH + native status banner); everything else is a
 *         work-package PATCH with lockVersion/409 handling.
 *         → { ok, openProjectId, url, applied, warnings }
 *
 *   POST  /api/openproject/projects/:externalProjectId/work-packages
 *         body = { subject, description?, typeName?, parentExternalId? }.
 *         Creates the WP in OpenProject and returns { ok, openProjectId, url }
 *         — the caller MUST persist openProjectId as the Kyndral entity's
 *         externalId so the new item is OpenProject-backed from birth.
 *
 *   GET   /api/openproject/link/:entityType/:externalId
 *         → { url } deep link (work_packages/{id} or projects/{identifier}).
 *
 *   GET   /api/openproject/status
 *         testConnection() passthrough for the IntegrationManagement page
 *         → { success, message }.
 *
 * DROP-IN (Kyndral server/routes.ts — or wherever app routes are registered):
 *   import { initOpenProjectRoutes } from "./routes/openproject.routes";
 *   import { OpenProjectWriteback } from "./openProjectWriteback";
 *   app.use(initOpenProjectRoutes(express.Router(), {
 *     writeback: new OpenProjectWriteback({ baseUrl, apiKey }), // or createOpenProjectWritebackFromAdapter(id)
 *     storage,                                                  // optional: notifications
 *   }));
 *
 * AUTH: these routes mutate the system of record — mount them BEHIND Kyndral's
 * existing authenticated-route middleware (the same isAuthenticated/requireAuth
 * chain the other /api/* routers use; e.g. pass `express.Router().use(requireAuth)`
 * as the router argument, or app.use("/", requireAuth, initOpenProjectRoutes(...))).
 * Do NOT mount them next to the unauthenticated /webhooks/* router.
 */
import express, { type Request, type Response, type Router } from "express";
import { z } from "zod";
import {
  OpenProjectApiError,
  type KyndralProjectChanges,
  type OpenProjectWriteback,
} from "../openProjectWriteback";

// ── Dependencies (structural — Kyndral's real services satisfy these) ────────

export interface OpenProjectRoutesDeps {
  writeback: OpenProjectWriteback;
  /** Optional: Kyndral storage for best-effort notifications on create. */
  storage?: { createNotification(n: Record<string, unknown>): Promise<unknown> };
}

// ── Validation ────────────────────────────────────────────────────────────────

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "expected YYYY-MM-DD");

/** Mirrors KyndralEntityChanges in server/openProjectWriteback.ts. */
const entityChangesSchema = z
  .object({
    name: z.string().min(1).optional(),
    description: z.string().optional(),
    status: z.string().min(1).optional(),
    priority: z.string().min(1).optional(),
    assigneeName: z.string().min(1).nullable().optional(),
    startDate: isoDate.nullable().optional(),
    dueDate: isoDate.nullable().optional(),
    percentComplete: z.number().min(0).max(100).optional(),
  })
  .strict()
  .refine((c) => Object.keys(c).length > 0, { message: "at least one field is required" });

const createWorkPackageSchema = z
  .object({
    subject: z.string().min(1),
    description: z.string().optional(),
    typeName: z.string().min(1).optional(),
    parentExternalId: z.union([z.string().min(1), z.number().int().positive()]).optional(),
  })
  .strict();

/** Project health → OpenProject native banner code ("at-risk" tolerated). */
const projectStatusSchema = z.enum(["on_track", "at_risk", "off_track"]);

function isProjectType(entityType: string): boolean {
  const t = entityType.trim().toLowerCase().replace(/[\s-]+/g, "_");
  return t === "project" || t === "portfolio" || t === "program";
}

/** Map an upstream OpenProject error to a sane HTTP status for the UI. */
function upstreamStatus(e: unknown): number {
  if (e instanceof OpenProjectApiError) {
    if (e.status === 404) return 404;
    if (e.status === 403 || e.status === 401) return 502; // OUR credential problem, not the caller's
    if (e.status === 422) return 422;
  }
  return 502;
}

// ── Router ────────────────────────────────────────────────────────────────────

export function initOpenProjectRoutes(router: Router, deps: OpenProjectRoutesDeps): Router {
  const { writeback } = deps;

  // User edited a synced entity in the Kyndral UI → push to OpenProject.
  router.patch(
    "/api/openproject/entities/:entityType/:externalId",
    express.json(),
    async (req: Request, res: Response) => {
      const { entityType, externalId } = req.params;
      const parsed = entityChangesSchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(400).json({ ok: false, error: "invalid body", details: parsed.error.flatten() });
        return;
      }
      try {
        let result;
        if (isProjectType(entityType)) {
          // Project edits use the project PATCH + native status banner path.
          const changes: KyndralProjectChanges = {
            name: parsed.data.name,
            description: parsed.data.description,
          };
          if (parsed.data.status !== undefined) {
            const code = projectStatusSchema.safeParse(
              parsed.data.status.trim().toLowerCase().replace(/[\s-]+/g, "_"),
            );
            if (!code.success) {
              res.status(400).json({
                ok: false,
                error: `project status must be one of on_track | at_risk | off_track (got "${parsed.data.status}")`,
              });
              return;
            }
            changes.status = code.data;
          }
          result = await writeback.pushProjectUpdate(externalId, changes);
        } else {
          result = await writeback.pushEntityUpdate(
            { externalId, entityType },
            parsed.data,
          );
        }
        res.json({
          ok: true,
          openProjectId: result.id,
          url: result.url,
          applied: result.applied,
          warnings: result.warnings,
        });
      } catch (e: any) {
        console.error(
          `[openproject-routes] PATCH ${entityType}/${externalId} failed:`,
          e?.message ?? e,
        );
        res.status(upstreamStatus(e)).json({ ok: false, error: e?.message ?? "write-back failed" });
      }
    },
  );

  // Item born in Kyndral → create in OpenProject, caller stores externalId.
  router.post(
    "/api/openproject/projects/:externalProjectId/work-packages",
    express.json(),
    async (req: Request, res: Response) => {
      const { externalProjectId } = req.params;
      const parsed = createWorkPackageSchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(400).json({ ok: false, error: "invalid body", details: parsed.error.flatten() });
        return;
      }
      try {
        const { id, url } = await writeback.createLinkedWorkPackage(externalProjectId, parsed.data);
        res.status(201).json({ ok: true, openProjectId: id, url });
        await deps.storage
          ?.createNotification({
            type: "info",
            title: "Work package created in OpenProject",
            message: `"${parsed.data.subject}" → OpenProject #${id}`,
            severity: "info",
            source: "openproject_writeback",
            sourceId: String(id),
          })
          .catch(() => {}); // notification is best-effort
      } catch (e: any) {
        console.error(
          `[openproject-routes] create WP in project ${externalProjectId} failed:`,
          e?.message ?? e,
        );
        res.status(upstreamStatus(e)).json({ ok: false, error: e?.message ?? "create failed" });
      }
    },
  );

  // Deep link for "Open in OpenProject" buttons.
  router.get("/api/openproject/link/:entityType/:externalId", (req: Request, res: Response) => {
    const { entityType, externalId } = req.params;
    res.json({ url: writeback.deepLink(entityType, externalId) });
  });

  // testConnection passthrough for the IntegrationManagement page.
  router.get("/api/openproject/status", async (_req: Request, res: Response) => {
    try {
      const result = await writeback.client.testConnection();
      res.status(result.success ? 200 : 502).json(result);
    } catch (e: any) {
      res.status(502).json({ success: false, message: e?.message ?? "connection test failed" });
    }
  });

  return router;
}

export default initOpenProjectRoutes;
