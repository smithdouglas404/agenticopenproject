/**
 * OpenProject gap tables for Kyndral-365 DOSv2 `shared/schema.ts`.
 *
 * Implements every row of the "Gaps to add" table in
 * docs/SCHEMA_AND_OPENPROJECT_MAPPING.md:
 *   High  — workPackageRelations, releases, workPackageCategories
 *           (+ tasks.startDate / tasks.completedDate, see ALTER notes below)
 *   Med   — okrEntityContributions (the OKR↔Epic↔Task glue),
 *           activityCostRates (+ timesheets.activityName),
 *           customFields sync columns (see ALTER notes below)
 *
 * PASTE INSTRUCTIONS (Kyndral repo):
 *   1. Copy everything between the PASTE-START / PASTE-END markers into
 *      `shared/schema.ts` (bottom of the file is fine — these tables only
 *      reference other tables via integer FK columns, see the
 *      `.references()` comments to wire the real constraints).
 *   2. Merge the imports below into the existing import lines at the top of
 *      `shared/schema.ts` (Kyndral already imports pgTable/serial/varchar/…
 *      from "drizzle-orm/pg-core" and createInsertSchema from "drizzle-zod";
 *      the only likely additions are `date` and `uniqueIndex`).
 *   3. Apply the four ALTER-style column additions listed at the bottom of
 *      this file to the existing `tasks`, `timesheets`, `customFields` tables.
 *   4. Migrate: `npm run db:push` (Kyndral's drizzle-kit push script) — or
 *      `npx drizzle-kit push` if no script exists. All columns are nullable
 *      or defaulted, so push is non-destructive on existing rows.
 *
 * Polymorphic entity references (fromEntityType/entityType + integer id)
 * deliberately have NO database FK — they can point at epics, features,
 * stories, tasks, issues or milestones. Integrity is enforced by the sync
 * layer, exactly like Kyndral's existing okrLinkages childEntity pattern.
 */
import {
  pgTable,
  serial,
  varchar,
  text,
  integer,
  decimal,
  timestamp,
  date,
  uniqueIndex,
} from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

// ─── PASTE-START ─────────────────────────────────────────────────────────────

// ── work_package_relations — typed dependencies (OpenProject /relations) ─────
// Replaces the thin `dependencies` table for cross-entity dependency/impact
// analysis. OpenProject relation types map onto relationType:
//   blocks/blocked → "blocks", follows/precedes → "follows",
//   relates → "relates_to", duplicates/duplicated → "duplicates".
export const workPackageRelations = pgTable("work_package_relations", {
  id: serial("id").primaryKey(),
  /** Integration/adapter id that synced this relation (e.g. "openproject"). */
  sourceSystemId: varchar("source_system_id", { length: 64 }),
  /** epic | feature | story | task | issue | milestone — polymorphic, no DB FK. */
  fromEntityType: varchar("from_entity_type", { length: 32 }).notNull(),
  fromEntityId: integer("from_entity_id").notNull(),
  toEntityType: varchar("to_entity_type", { length: 32 }).notNull(),
  toEntityId: integer("to_entity_id").notNull(),
  /** blocks | follows | relates_to | duplicates */
  relationType: varchar("relation_type", { length: 32 }).notNull().default("relates_to"),
  /** OpenProject relation id — the sync key for upserts. */
  externalId: varchar("external_id", { length: 64 }),
  description: text("description"),
  /** Working-day lag for follows relations (OpenProject `lag`). */
  lagDays: integer("lag_days"),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// ── releases — OpenProject versions/releases ─────────────────────────────────
// OpenProject "versions" (used as releases/backlog buckets) land here.
// Linking to milestones/PIs: a release is delivery-scoped, so when a synced
// version has a releaseDate, create/refresh a `milestones` row named after the
// release and, if the date falls inside a programIncrement window, stamp that
// PI's id on the milestone — keeps the SAFe views aware of releases without a
// hard FK from this table.
export const releases = pgTable("releases", {
  id: serial("id").primaryKey(),
  projectId: integer("project_id").notNull(), // .references(() => projects.id)
  name: varchar("name", { length: 255 }).notNull(),
  description: text("description"),
  /** open | locked | closed (OpenProject version status, verbatim). */
  status: varchar("status", { length: 32 }).notNull().default("open"),
  startDate: date("start_date"),
  releaseDate: date("release_date"),
  /** OpenProject version id — the sync key for upserts. */
  externalId: varchar("external_id", { length: 64 }),
  sourceSystemId: varchar("source_system_id", { length: 64 }),
  createdAt: timestamp("created_at").defaultNow(),
  updatedAt: timestamp("updated_at").defaultNow(),
});

// ── work_package_categories — OpenProject categories ────────────────────────
// NOTE: also add `categoryId: integer("category_id")` to `tasks`, `stories`
// and `features` (pointing .references(() => workPackageCategories.id)) so
// synced work items can carry their OpenProject category.
export const workPackageCategories = pgTable("work_package_categories", {
  id: serial("id").primaryKey(),
  projectId: integer("project_id").notNull(), // .references(() => projects.id)
  name: varchar("name", { length: 255 }).notNull(),
  /** OpenProject category id — the sync key for upserts. */
  externalId: varchar("external_id", { length: 64 }),
  sourceSystemId: varchar("source_system_id", { length: 64 }),
});

// ── okr_entity_contributions — the OKR↔Epic↔Task glue ───────────────────────
// `okrLinkages` records *that* an entity aligns to an OKR; this table records
// *how much it contributes*, so entity progress can roll up into KR progress:
//   KR.progress = Σ entity.progress × contributionPct/100
// (see server/okrRollupService.ts). One entity may contribute to many KRs.
// Agent-inferred rows (inferredBy="agent") are derived from okrLinkages
// alignment scores; human rows (inferredBy="human") always win over agent
// rows for the same KR.
export const okrEntityContributions = pgTable(
  "okr_entity_contributions",
  {
    id: serial("id").primaryKey(),
    okrId: integer("okr_id").notNull(), // .references(() => okrs.id)
    /** Null = contributes to the OKR as a whole rather than one KR. */
    keyResultId: integer("key_result_id"), // .references(() => keyResults.id)
    /** epic | feature | story | task | project — polymorphic, no DB FK. */
    entityType: varchar("entity_type", { length: 32 }).notNull(),
    entityId: integer("entity_id").notNull(),
    /** Share (0–100) of the key result this entity drives. */
    contributionPct: decimal("contribution_pct", { precision: 5, scale: 2 }).notNull(),
    /** Optional relative weight among contributors (default 1). */
    weight: decimal("weight", { precision: 5, scale: 2 }).default("1"),
    /** agent | human — human rows override agent rows in the rollup. */
    inferredBy: varchar("inferred_by", { length: 16 }).notNull().default("agent"),
    /** 0–1; for agent rows this is the okrLinkages alignmentScore. */
    confidence: decimal("confidence", { precision: 4, scale: 3 }),
    createdAt: timestamp("created_at").defaultNow(),
    updatedAt: timestamp("updated_at").defaultNow(),
  },
  (table) => ({
    contributionUnique: uniqueIndex("okr_entity_contrib_kr_entity_idx").on(
      table.keyResultId,
      table.entityType,
      table.entityId,
    ),
  }),
);

// ── activity_cost_rates — turn spentTime into actual cost (EVM) ──────────────
// OpenProject time entries carry an `activity` (Development, Management, …).
// actualCost = Σ timesheets.hours × rate(timesheets.activityName, date) —
// pick the row with the latest effectiveFrom ≤ the time entry's date.
export const activityCostRates = pgTable("activity_cost_rates", {
  id: serial("id").primaryKey(),
  /** Matches timesheets.activityName (see ALTER note below). */
  activityName: varchar("activity_name", { length: 128 }).notNull(),
  hourlyRate: decimal("hourly_rate", { precision: 10, scale: 2 }).notNull(),
  currency: varchar("currency", { length: 3 }).notNull().default("USD"),
  effectiveFrom: date("effective_from").notNull(),
  sourceSystemId: varchar("source_system_id", { length: 64 }),
});

// ── drizzle-zod insert schemas + inferred types ──────────────────────────────

export const insertWorkPackageRelationSchema = createInsertSchema(workPackageRelations).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});
export type InsertWorkPackageRelation = z.infer<typeof insertWorkPackageRelationSchema>;
export type WorkPackageRelation = typeof workPackageRelations.$inferSelect;

export const insertReleaseSchema = createInsertSchema(releases).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});
export type InsertRelease = z.infer<typeof insertReleaseSchema>;
export type Release = typeof releases.$inferSelect;

export const insertWorkPackageCategorySchema = createInsertSchema(workPackageCategories).omit({
  id: true,
});
export type InsertWorkPackageCategory = z.infer<typeof insertWorkPackageCategorySchema>;
export type WorkPackageCategory = typeof workPackageCategories.$inferSelect;

export const insertOkrEntityContributionSchema = createInsertSchema(okrEntityContributions).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});
export type InsertOkrEntityContribution = z.infer<typeof insertOkrEntityContributionSchema>;
export type OkrEntityContribution = typeof okrEntityContributions.$inferSelect;

export const insertActivityCostRateSchema = createInsertSchema(activityCostRates).omit({
  id: true,
});
export type InsertActivityCostRate = z.infer<typeof insertActivityCostRateSchema>;
export type ActivityCostRate = typeof activityCostRates.$inferSelect;

// ─── PASTE-END ───────────────────────────────────────────────────────────────

/**
 * ALTER-style additions to EXISTING tables (add these columns to the existing
 * pgTable definitions in shared/schema.ts, then `npm run db:push`):
 *
 * 1. tasks — schedule variance needs real dates (OpenProject has both):
 *      startDate: date("start_date"),          // OpenProject startDate
 *      completedDate: date("completed_date"),  // set when status → done
 *
 * 2. timesheets — cost-rate join key for EVM actual cost:
 *      activityName: varchar("activity_name", { length: 128 }),
 *      // OpenProject time_entry.activity.name; joins activityCostRates.activityName
 *
 * 3. customFields — bidirectional custom-field mapping:
 *      externalCustomFieldId: varchar("external_custom_field_id", { length: 64 }),
 *      // e.g. OpenProject "customField12"
 *      syncDirection: varchar("sync_direction", { length: 16 }).default("inbound"),
 *      // inbound | outbound | bidirectional | none
 *      transformScript: text("transform_script"),
 *      // optional value transform applied during sync (expression/JS snippet)
 *
 * 4. tasks / stories / features — OpenProject category on work items:
 *      categoryId: integer("category_id"), // .references(() => workPackageCategories.id)
 */
