# Mock data → real data: the cutover plan for Kyndral-365 v2

Kyndral v2 demos beautifully because it ships with demo data. That is also why
a skeptic can dismiss it. This is the plan to kill the demo data so that
**every number on screen traces to a real source** — the same grounding bar as
`docs/GROUNDING_AND_HALLUCINATION.md`, applied to the data itself.

## 1. Inventory: what is mock in v2 today

Exact file names vary by branch — search for `seed`, `demo`, `sample`,
`fixture`, `faker` under `server/` and `scripts/`. Categorically, the mock
layer is:

| Mock artifact | Where it shows up | Real replacement |
|---|---|---|
| Demo projects/epics/features/stories/tasks (seed scripts) | every portfolio/project page | OpenProject sync (`openProjectClient.syncProject`) |
| Fabricated EVM numbers (earnedValue, BAC/EAC, CPI/SPI seeded on projects) | exec dashboards, project health | computed: timesheets × `activityCostRates` vs baseline |
| Sample OKRs + key results with hand-typed progress | OKR dashboard | setup-screen entry + `okrRollupService` rollups |
| Pre-seeded okrLinkages / alignment scores | alignment views | agent inference over synced entities, human-confirmed |
| Demo risks/issues with invented probability×impact | risk register | synced Bug/Risk WPs + risk setup screen |
| Sample timesheets/actuals | cost & capacity views | OpenProject time entries (spentTime sync) |
| Demo divisions/portfolios/value streams | org navigation | setup screens (org structure is user-entered, not synced) |
| Canned agent findings/insights/notifications | insights feed | live agent runs over real data only |

## 2. The rule

> **Every number the UI renders must trace to exactly one of:**
> 1. **OpenProject sync** (system of record — work items, dates, progress, time entries),
> 2. **user setup-screen entry** (org structure, OKR targets, cost rates, policies), or
> 3. **a computed formula in code** over (1) and (2) — EVM, rollups, risk scores.
>
> If a value can't name its source, it doesn't render. No fourth category.

This is enforceable in review: any PR that inserts literals into business
tables, or any UI component with hardcoded metrics, is a regression.

## 3. Cutover steps

1. **Connect OpenProject and run the first sync.**
   Register the `openproject` integration (`server/openProjectClient.ts`, steps
   in this folder's README), run `syncOpenProject` for the real projects, and
   enable the webhook for real-time updates. Verify row counts in
   projects/features/stories/tasks match the OpenProject instance.

2. **Flag off the seed scripts.**
   Gate every seeder behind an env flag, default OFF:
   ```ts
   if (process.env.SEED_DEMO_DATA === "true") await seedDemoData();
   ```
   Same pattern for any in-route "if table empty, fabricate" fallbacks — those
   are seeders in disguise. Then purge seeded rows from the real database
   (seeded rows are identifiable: no `externalId`/`sourceSystemId`, or created
   before the integration's first sync). Keep `SEED_DEMO_DATA=true` only in
   the demo environment.

3. **Setup screens for what sync can't supply.**
   Divisions/portfolios/value streams, OKRs + key results (objective text,
   targetValue, unit, weight), `activityCostRates`, policies/thresholds. These
   are legitimate human inputs (category 2) — the screens mostly exist; the
   cutover task is making them the *only* path that populates those tables.

4. **Computed fields go live.**
   - OKR/KR progress: `server/okrRollupService.ts` —
     `syncRollupsToOkrTable()` after each sync, KR progress =
     Σ entity.progress × contributionPct/100, with the `formula` audit string.
   - EVM: actualCost = Σ `timesheets.hours` × `activityCostRates.hourlyRate`
     (joined on `activityName`, latest `effectiveFrom` ≤ entry date);
     earnedValue = % complete × BAC; CPI/SPI follow. BAC/baseline dates are
     setup-screen inputs.
   - Risk score = probability × impact from real register entries.
   Delete every code path that writes these as constants.

5. **Verification checklist (per major page).**
   - [ ] **ProjectDetailPage**: every work item shows an `externalId` that opens
         in OpenProject; edit a WP in OpenProject → webhook updates the page.
   - [ ] **Portfolio/exec dashboard**: project counts and statuses equal the
         OpenProject instance; no project exists that OpenProject lacks.
   - [ ] **OKR dashboard**: each KR's progress matches `GET
         /api/okrs/:id/rollup` and the `formula` string names real entities;
         changing a task's % done in OpenProject moves the KR after sync.
   - [ ] **EVM/financials**: actualCost recomputes from timesheets ×
         activityCostRates by hand for one project; zero time entries ⇒ zero
         actual cost (not a pretty fake curve).
   - [ ] **Risk register**: only user-entered or synced risks; scores recompute
         when probability/impact change.
   - [ ] **Insights/notifications feed**: every agent finding cites entity ids
         that exist in the synced data.
   - [ ] **Grep gate**: `SEED_DEMO_DATA` unset ⇒ fresh database + first sync
         produces zero rows without a `sourceSystemId` or a user audit trail.

## 4. Honest note: what will look EMPTY after cutover — and why that's correct

- **Agent track records start at n/a.** Outcome-tracking (did the prediction
  come true) needs elapsed time. Showing "no track record yet" is the credible
  state; a pre-filled accuracy score would be exactly the hallucination the
  grounding doc warns against.
- **EVM curves need time entries.** Until teams log time in OpenProject (and
  cost rates are entered), actual-cost and CPI panels show "insufficient data".
  A flat/empty chart on day one is evidence the numbers are real.
- **OKR progress starts at 0** until contributions exist (agent-inferred from
  linkages, then human-confirmed) and synced entities report progress. The
  dashboard earns its numbers as delivery happens.
- **Trend/velocity widgets need history.** Anything "vs last sprint/PI" is
  blank for the first cycle by definition.
- **Some divisions/portfolios will be sparse** — that's the true state of the
  org's data, now visible instead of papered over.

The demo environment keeps `SEED_DEMO_DATA=true` for sales walkthroughs;
production never sets it. "Empty but true" beats "full but fabricated" in
front of any buyer who asks the second question.
