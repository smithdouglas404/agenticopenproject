/**
 * OKR rollup routes for the Kyndral-365 server.
 *
 *   GET  /api/okrs/:id/rollup
 *        Computed (never stored-stale) OKR progress: weighted KR rollups with
 *        the full contributor breakdown and the `formula` audit string from
 *        server/okrRollupService.ts.
 *
 *   POST /api/okrs/:okrId/key-results/:krId/contributions
 *        Upsert a HUMAN contribution row (inferredBy:"human") — body
 *        { entityType, entityId, contributionPct }. Human rows override
 *        agent-inferred ones in the rollup. Responds with the saved row plus
 *        the freshly recomputed KR rollup so the UI can update in place.
 *
 * DROP-IN (Kyndral server/routes.ts — or wherever app routes are registered):
 *   import { initOkrRollupRoutes } from "./routes/okrRollup.routes";
 *   app.use(initOkrRollupRoutes(express.Router(), {
 *     storage,                                    // implements RollupStorage
 *     upsertContribution: (row) => storage.upsertOkrEntityContribution(row),
 *     // ^ ON CONFLICT (key_result_id, entity_type, entity_id) DO UPDATE —
 *     //   the unique index in shared/schema.openproject-gaps.ts makes this a
 *     //   one-liner with Drizzle's .onConflictDoUpdate().
 *   }));
 */
import express, { type Request, type Response, type Router } from "express";
import { z } from "zod";
import { OkrRollupService, type ContributionRow, type RollupStorage } from "../okrRollupService";

// ── Dependencies (structural — Kyndral's storage satisfies these) ────────────

export interface OkrRollupRouteDeps {
  /** Kyndral storage; see RollupStorage in server/okrRollupService.ts. */
  storage: RollupStorage;
  /**
   * Upsert keyed on (keyResultId, entityType, entityId) — the unique index in
   * okrEntityContributions. Returns the saved row.
   */
  upsertContribution(row: ContributionRow): Promise<ContributionRow>;
}

// ── Validation ───────────────────────────────────────────────────────────────

const contributionBodySchema = z.object({
  entityType: z.enum(["epic", "feature", "story", "task", "project"]),
  entityId: z.number().int().positive(),
  /** Share (0–100) of the key result this entity drives. */
  contributionPct: z.number().min(0).max(100),
});

function intParam(value: string): number | null {
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : null;
}

// ── Router ───────────────────────────────────────────────────────────────────

export function initOkrRollupRoutes(router: Router, deps: OkrRollupRouteDeps): Router {
  const service = new OkrRollupService(deps.storage);

  router.get("/api/okrs/:id/rollup", async (req: Request, res: Response) => {
    const okrId = intParam(req.params.id);
    if (okrId === null) {
      res.status(400).json({ error: "okr id must be a positive integer" });
      return;
    }
    try {
      const rollup = await service.rollUpOkr(okrId);
      res.json(rollup);
    } catch (e: any) {
      console.error(`[okr-rollup] GET rollup for OKR ${okrId} failed:`, e?.message ?? e);
      res.status(500).json({ error: e?.message ?? "rollup failed" });
    }
  });

  router.post(
    "/api/okrs/:okrId/key-results/:krId/contributions",
    express.json(),
    async (req: Request, res: Response) => {
      const okrId = intParam(req.params.okrId);
      const keyResultId = intParam(req.params.krId);
      if (okrId === null || keyResultId === null) {
        res.status(400).json({ error: "okrId and krId must be positive integers" });
        return;
      }
      const parsed = contributionBodySchema.safeParse(req.body);
      if (!parsed.success) {
        res.status(400).json({ error: "invalid body", details: parsed.error.flatten() });
        return;
      }
      try {
        const saved = await deps.upsertContribution({
          okrId,
          keyResultId,
          entityType: parsed.data.entityType,
          entityId: parsed.data.entityId,
          contributionPct: parsed.data.contributionPct,
          inferredBy: "human", // human rows win over agent-inferred rows
          confidence: 1,
        });
        // Recompute so the caller sees the effect of the override immediately.
        const rollup = await service.rollUpKeyResult(keyResultId);
        res.status(201).json({ contribution: saved, rollup });
      } catch (e: any) {
        console.error(`[okr-rollup] POST contribution for KR ${keyResultId} failed:`, e?.message ?? e);
        res.status(500).json({ error: e?.message ?? "contribution upsert failed" });
      }
    },
  );

  return router;
}

export default initOkrRollupRoutes;
