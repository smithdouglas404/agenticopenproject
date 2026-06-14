/**
 * ontologyAlias — zero-downtime URL rename for the ontology API (Kyndral-365).
 *
 * The ontology UI route is historically `/api/palantir/ontology/*` — a name from
 * before FalkorDB replaced the old provider (see docs/ONTOLOGY_LAYER.md). The
 * canonical name is now `/api/ontology/*`. To rename WITHOUT a flag day, this
 * mounts the SAME handler on BOTH stems so every existing client URL keeps
 * working while the client is migrated:
 *
 *   /api/ontology/*          ← new, canonical
 *   /api/palantir/ontology/* ← legacy alias (remove after the client cutover)
 *
 * Both URLs are live simultaneously — no request 404s during the migration.
 * Cutover steps: docs/ONTOLOGY_RENAME.md. Remove the legacy mount in the
 * release AFTER the client is confirmed to use `/api/ontology`.
 *
 * DROP-IN (Kyndral server/routes.ts — behind the same auth the ontology API
 * already uses):
 *   import { mountOntologyAlias } from "./routes/ontologyAlias";
 *   mountOntologyAlias(app, ontologyRouter); // ontologyRouter = your existing handler
 */
import type { Express, RequestHandler, Router } from "express";

/** The new canonical mount point. */
export const ONTOLOGY_PATH = "/api/ontology";
/** The legacy alias — DELETE this mount after the client cutover. */
export const LEGACY_ONTOLOGY_PATH = "/api/palantir/ontology";

/**
 * Mount the ontology handler on both the canonical and legacy stems.
 *
 * @param app     the Express application (or a Router) to mount onto.
 * @param handler the existing ontology Router/middleware — the SAME instance is
 *                mounted twice, so there is one source of truth for behavior.
 *
 * Because both mounts share the handler, the handler must define its sub-paths
 * RELATIVE to the mount (e.g. `router.get("/objects/:type", …)`), exactly as it
 * does today under `/api/palantir/ontology`.
 */
export function mountOntologyAlias(
  app: Express,
  handler: Router | RequestHandler,
): void {
  // Canonical first (so it shows first in route listings), then the legacy alias.
  app.use(ONTOLOGY_PATH, handler);
  app.use(LEGACY_ONTOLOGY_PATH, handler);
}

export default mountOntologyAlias;
