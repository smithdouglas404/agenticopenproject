/**
 * OKR rollup service for the Kyndral-365 server — the OKR↔Epic↔Task glue.
 *
 * Implements the highest-value OKR addition from
 * docs/SCHEMA_AND_OPENPROJECT_MAPPING.md: `okrLinkages` records *that* an
 * entity aligns to an OKR; `okrEntityContributions` (see
 * shared/schema.openproject-gaps.ts) records *how much*. This service turns
 * those rows into KR/OKR progress numbers:
 *
 *   KR.progress  = Σ entity.progress × contributionPct/100   (clamped 0–100)
 *   OKR.progress = Σ KR.progress × KR.weight / Σ KR.weight
 *
 * GROUNDING (see docs/GROUNDING_AND_HALLUCINATION.md): every result is
 * deterministic arithmetic over synced data and carries a human-readable
 * `formula` string plus the full contributor breakdown — "the numbers are
 * computed, not generated". No LLM call anywhere in this file; even
 * inferContributions() is pure math over existing alignment scores.
 *
 * SELF-CONTAINED: depends only on the minimal RollupStorage interface below.
 * Kyndral's DatabaseStorage implements each method with a trivial Drizzle
 * query (examples on the interface). Decimal columns come back from Drizzle
 * as strings — all numeric inputs accept `number | string` and are coerced.
 *
 * DROP-IN: place in Kyndral's `server/` next to openProjectClient.ts and
 * mount server/routes/okrRollup.routes.ts (see that file's header).
 */

// ── Row shapes (structural — Kyndral's Drizzle rows satisfy these) ───────────

/** Numeric value as Drizzle returns it: number, decimal-as-string, or null. */
export type NumberLike = number | string | null | undefined;

/** A keyResults row (only the fields the rollup needs). */
export interface KeyResultRow {
  id: number;
  okrId: number;
  /** Relative weight within the OKR; defaults to 1 when null. */
  weight?: NumberLike;
  targetValue?: NumberLike;
  currentValue?: NumberLike;
}

/** An okrEntityContributions row (only the fields the rollup needs). */
export interface ContributionRow {
  okrId: number;
  keyResultId: number | null;
  /** epic | feature | story | task | project */
  entityType: string;
  entityId: number;
  /** Share (0–100) of the key result this entity drives. */
  contributionPct: NumberLike;
  weight?: NumberLike;
  /** "agent" | "human" — human rows override agent rows (see effectiveContributions). */
  inferredBy?: string | null;
  /** 0–1; for agent rows, the okrLinkages alignmentScore it was derived from. */
  confidence?: NumberLike;
}

/**
 * Minimal storage surface. Kyndral's storage layer implements these trivially
 * with Drizzle queries, e.g.:
 *
 *   async getContributions(keyResultId: number) {
 *     return db.select().from(okrEntityContributions)
 *       .where(eq(okrEntityContributions.keyResultId, keyResultId));
 *   }
 *
 *   async getEntityProgress(entityType: string, entityId: number) {
 *     const table = { epic: epics, feature: features, story: stories,
 *                     task: tasks, project: projects }[entityType];
 *     const [row] = await db.select({ progress: table.progress })
 *       .from(table).where(eq(table.id, entityId));
 *     return row?.progress == null ? null : Number(row.progress);
 *   }
 */
export interface RollupStorage {
  getKeyResults(okrId: number): Promise<KeyResultRow[]>;
  getContributions(keyResultId: number): Promise<ContributionRow[]>;
  /** Entity percentageDone (0–100), or null when unknown / not yet synced. */
  getEntityProgress(entityType: string, entityId: number): Promise<number | null>;
}

// ── Result shapes ────────────────────────────────────────────────────────────

export interface ContributorBreakdown {
  entityType: string;
  entityId: number;
  /** The entity's own progress, 0–100. */
  progress: number;
  /** Effective contribution share used (after human-override + renormalization). */
  contributionPct: number;
  /** progress × contributionPct/100 — this contributor's slice of the KR. */
  weighted: number;
}

export interface KeyResultRollup {
  keyResultId: number;
  /** 0–100, deterministic. */
  progress: number;
  contributors: ContributorBreakdown[];
  /** Entities skipped because their progress is null (not yet synced/scored). */
  skipped: Array<{ entityType: string; entityId: number; reason: string }>;
  /** Human-readable audit trail of the exact arithmetic (grounding pattern). */
  formula: string;
}

export interface OkrRollup {
  okrId: number;
  /** 0–100; weighted average of the KRs' rolled progress. */
  progress: number;
  keyResults: Array<KeyResultRollup & { weight: number }>;
  formula: string;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function num(v: NumberLike, fallback = 0): number {
  if (v === null || v === undefined) return fallback;
  const n = typeof v === "number" ? v : parseFloat(v);
  return Number.isFinite(n) ? n : fallback;
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, v));
}

function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

/**
 * Human override rule: if ANY human-entered row exists for a KR, use ONLY the
 * human rows — agents propose, humans dispose.
 */
export function effectiveContributions(rows: ContributionRow[]): ContributionRow[] {
  const human = rows.filter((r) => r.inferredBy === "human");
  return human.length > 0 ? human : rows;
}

// ── Service ──────────────────────────────────────────────────────────────────

export class OkrRollupService {
  constructor(private readonly storage: RollupStorage) {}

  /**
   * KR progress = Σ entity.progress × contributionPct/100, clamped 0–100.
   * Entities with null progress are skipped, and the remaining contributors'
   * shares are renormalized so they carry the skipped entities' share
   * proportionally (the KR is judged on what is measurable today).
   */
  async rollUpKeyResult(keyResultId: number): Promise<KeyResultRollup> {
    const rows = effectiveContributions(await this.storage.getContributions(keyResultId));
    const humanOverride = rows.some((r) => r.inferredBy === "human");

    // Resolve progress per contributor; partition present vs skipped.
    const present: Array<{ row: ContributionRow; progress: number; pct: number }> = [];
    const skipped: KeyResultRollup["skipped"] = [];
    for (const row of rows) {
      const progress = await this.storage.getEntityProgress(row.entityType, row.entityId);
      if (progress === null || progress === undefined) {
        skipped.push({ entityType: row.entityType, entityId: row.entityId, reason: "null progress" });
      } else {
        present.push({ row, progress: clamp(num(progress), 0, 100), pct: num(row.contributionPct) });
      }
    }

    // Renormalize: scale the present contributors' shares so they sum to the
    // total declared share (skipped entities' slice is redistributed pro rata).
    const totalPct = rows.reduce((s, r) => s + num(r.contributionPct), 0);
    const presentPct = present.reduce((s, p) => s + p.pct, 0);
    const scale = presentPct > 0 ? totalPct / presentPct : 0;

    const contributors: ContributorBreakdown[] = present.map((p) => {
      const effectivePct = round2(p.pct * scale);
      return {
        entityType: p.row.entityType,
        entityId: p.row.entityId,
        progress: round2(p.progress),
        contributionPct: effectivePct,
        weighted: round2((p.progress * effectivePct) / 100),
      };
    });

    const raw = contributors.reduce((s, c) => s + c.weighted, 0);
    const progress = round2(clamp(raw, 0, 100));

    const terms = contributors
      .map((c) => `(${c.entityType}#${c.entityId} ${c.progress}×${c.contributionPct}% = ${c.weighted})`)
      .join(" + ");
    const notes = [
      humanOverride ? "human-entered contributions override agent rows" : null,
      skipped.length > 0
        ? `${skipped.length} contributor(s) skipped for null progress, shares renormalized ×${round2(scale)}`
        : null,
    ].filter(Boolean);
    const formula =
      contributors.length === 0
        ? `KR#${keyResultId} progress = 0 (no measurable contributors${skipped.length ? `; ${skipped.length} skipped for null progress` : ""})`
        : `KR#${keyResultId} progress = Σ entity.progress × contributionPct/100 = ${terms} = ${progress} (clamped 0–100${notes.length ? `; ${notes.join("; ")}` : ""})`;

    return { keyResultId, progress, contributors, skipped, formula };
  }

  /**
   * OKR progress = weighted average of its KRs' rolled progress
   * (weight = keyResults.weight, defaulting to 1 when absent).
   */
  async rollUpOkr(okrId: number): Promise<OkrRollup> {
    const krs = await this.storage.getKeyResults(okrId);
    const keyResults: OkrRollup["keyResults"] = [];
    for (const kr of krs) {
      const rollup = await this.rollUpKeyResult(kr.id);
      keyResults.push({ ...rollup, weight: num(kr.weight, 1) || 1 });
    }

    const totalWeight = keyResults.reduce((s, k) => s + k.weight, 0);
    const progress =
      totalWeight > 0
        ? round2(clamp(keyResults.reduce((s, k) => s + k.progress * k.weight, 0) / totalWeight, 0, 100))
        : 0;

    const terms = keyResults.map((k) => `(KR#${k.keyResultId} ${k.progress}×${k.weight})`).join(" + ");
    const formula =
      keyResults.length === 0
        ? `OKR#${okrId} progress = 0 (no key results)`
        : `OKR#${okrId} progress = Σ KR.progress × weight / Σ weight = [${terms}] / ${round2(totalWeight)} = ${progress}`;

    return { okrId, progress, keyResults, formula };
  }

  /**
   * Derive contribution rows from existing okrLinkages — alignment without
   * magnitude becomes magnitude: per key result, distribute contributionPct
   * proportional to alignmentScore, normalized to sum to 100.
   *
   * DETERMINISTIC inference, no LLM call (the alignment scores were the
   * AI-inferred part, upstream in okrLinkages). Rows are marked
   * inferredBy:"agent" with confidence = alignmentScore, so any later
   * human-entered row for the same KR overrides them (see
   * effectiveContributions). Persist the result via
   * storage.createOkrEntityContribution / upsert on (keyResultId, entityType,
   * entityId).
   */
  inferContributions(okrId: number, candidates: LinkageCandidate[]): ContributionRow[] {
    // Group per key result (null = OKR-level linkage).
    const byKr = new Map<number | null, LinkageCandidate[]>();
    for (const c of candidates) {
      const key = c.keyResultId ?? null;
      const list = byKr.get(key) ?? [];
      list.push(c);
      byKr.set(key, list);
    }

    const out: ContributionRow[] = [];
    for (const [keyResultId, group] of byKr) {
      const totalScore = group.reduce((s, c) => s + Math.max(0, num(c.alignmentScore)), 0);
      for (const c of group) {
        const score = Math.max(0, num(c.alignmentScore));
        // Equal split when every score is 0 (aligned, but unscored).
        const pct = totalScore > 0 ? (score / totalScore) * 100 : 100 / group.length;
        out.push({
          okrId,
          keyResultId,
          entityType: c.entityType,
          entityId: c.entityId,
          contributionPct: round2(pct),
          weight: 1,
          inferredBy: "agent",
          confidence: round2(clamp(score, 0, 1)),
        });
      }
    }
    return out;
  }
}

/** An okrLinkages row reduced to what inference needs. */
export interface LinkageCandidate {
  /** Null/undefined = linked to the OKR as a whole, not a specific KR. */
  keyResultId?: number | null;
  /** epic | feature | story | task | project */
  entityType: string;
  entityId: number;
  /** 0–1, from okrLinkages.alignmentScore. */
  alignmentScore: NumberLike;
}

// ── Write-back skeleton ──────────────────────────────────────────────────────

/** Write surface for persisting rollups — Kyndral's storage already has these
 * (or trivially adds them: `db.update(keyResults).set(patch).where(eq(...))`). */
export interface RollupWriteStorage extends RollupStorage {
  updateKeyResult(
    id: number,
    patch: { progress?: number; currentValue?: number },
  ): Promise<unknown>;
  updateOkr(id: number, patch: { progress?: number }): Promise<unknown>;
}

/**
 * Persist computed rollups back onto the okrs / keyResults tables so the
 * existing OKR dashboard renders rolled-up delivery without UI changes.
 * Call after each sync run (end of syncOpenProject) or on a schedule.
 */
export async function syncRollupsToOkrTable(
  storage: RollupWriteStorage,
  okrIds: number[],
): Promise<OkrRollup[]> {
  const service = new OkrRollupService(storage);
  const results: OkrRollup[] = [];

  for (const okrId of okrIds) {
    const rollup = await service.rollUpOkr(okrId);

    for (const kr of rollup.keyResults) {
      // Only overwrite KRs that actually have contribution rows — manually
      // tracked KRs (no contributors and nothing skipped) keep their values.
      if (kr.contributors.length === 0 && kr.skipped.length === 0) continue;

      const krRow = (await storage.getKeyResults(okrId)).find((k) => k.id === kr.keyResultId);
      const target = krRow?.targetValue == null ? null : Number(krRow.targetValue);
      await storage.updateKeyResult(kr.keyResultId, {
        // kr.progress ← rolled 0–100
        progress: kr.progress,
        // kr.currentValue ← progress applied to the target, when one exists
        // (e.g. target 40 deals × 65% = 26). Omit for unit-less KRs.
        ...(target != null && Number.isFinite(target)
          ? { currentValue: Math.round(((target * kr.progress) / 100) * 100) / 100 }
          : {}),
      });
    }

    // okr.progress ← weighted KR average. (If the okrs table keeps a separate
    // computed/audit column, also persist rollup.formula there.)
    await storage.updateOkr(okrId, { progress: rollup.progress });
    results.push(rollup);
  }

  return results;
}
