# OpenProject → Kyndral-365 (v2) field mapping + schema additions

Scope: Kyndral-365 DOSv2 (`shared/schema.ts`, 94 tables; Palantir ontology layer
via `OntologyDataProvider` / `/api/palantir/ontology/*`). This answers #1: expose
OpenProject PPM features and map Epics/Tasks/OKRs through the ontology.

## Where OpenProject data lands

**Important v2 detail:** the UI reads from the **Palantir ontology objects**, not
raw tables. So the connector should write to the ontology objects (`Project`,
`Feature`, `Story`, `Task`, `Risk`) via `OntologyDataProvider`, which persist to
Postgres + Palantir. The `openProjectClient.ts` in this folder maps to the SAFe
storage entities; on the Kyndral side, route those through `OntologyDataProvider`
so the existing pages render them.

## Type routing (the ontology mapping)

| OpenProject WP type | Kyndral entity (ontology object) |
|---|---|
| Epic | `epics` (→ `safe:Epic`) |
| Capability | `capabilities` (→ `safe:Capability`) |
| Feature | `features` (→ `safe:Feature`) |
| User Story / Story | `stories` (→ `safe:Story`) |
| Task | `tasks` (→ `pm:Task`) |
| Bug | `issues` (→ `pm:Issue`) |
| Milestone | `milestones` (→ `pm:Milestone`) |

Hierarchy: OpenProject `parent` → `epicId`/`featureId`/`storyId` FKs.

## Field mapping (≈85% covered by v2 today)

| OpenProject field | Kyndral v2 field | Note |
|---|---|---|
| id | `ontologyEntities.externalId` | sync key |
| subject | `<entity>.name` | type-routed |
| description | `<entity>.description` | |
| status | `<entity>.status` | via value-map (New→backlog, In progress→in_progress, Closed→done, Rejected→cancelled) |
| priority | `<entity>.priority` | Low→low, Normal→medium, High→high, Immediate→critical |
| assignee | `tasks.assignee` / `issues.assignedTo` | |
| dueDate | `stories.dueDate` / `tasks.dueDate` | |
| estimatedTime | `tasks.effortHours` | ISO-8601 PT → hours |
| spentTime | `timesheets.hours` (aggregate) | ✅ v2 has timesheets |
| percentageDone | `<entity>` progress | |
| parent | hierarchy FKs | ✅ mapped |
| storyPoints | `features/stories.storyPoints` | |
| customField_* | `customFieldValues` (via `customFields`) | ✅ flexible |
| project | `projects` (+ SAFe `portfolioId`/`valueStreamId`) | |

**Kyndral fields OpenProject can't supply** (computed or setup-screen):
SAFe level assignments, EVM (earnedValue/BAC/EAC/CPI/SPI), risk numerics, OKR
progress/alignment, ROI, agent-driven fields. These are derived from the synced
actuals (timesheets → EVM) or entered in setup screens (divisions/OKRs/policies).

## Gaps to add (prioritized) — to fully expose OpenProject PPM

| Pri | Addition | Status in v2 | Why |
|---|---|---|---|
| **High** | `task.startDate` (+ completedDate) | ✗ missing | schedule variance; OpenProject has startDate |
| **High** | `work_package_relations` table (from→to, relationType: blocks/relates_to/duplicates) | ⚠️ only thin `dependencies` | real dependency/impact analysis |
| **High** | `releases` table (project→version→releaseDate, link to milestones/PIs) | ✗ missing | OpenProject versions/releases |
| **High** | `work_package_categories` (+ FK on work items) | ✗ missing | OpenProject categories |
| **Med** | `okr_entity_contributions` (okrId → entity → contribution %) | ✗ missing | lets an entity contribute to multiple OKRs; rolls entity progress into KRs — the OKR↔Epic↔Task glue you want |
| **Med** | `activity_cost_rates` (+ TimeEntry.activity) | ✗ missing | turns spentTime into actual cost for EVM |
| **Med** | enhance `customFields` (externalCustomFieldId, syncDirection, transformScript) | ⚠️ partial | bidirectional custom-field mapping |
| **Low** | `work_package_attachments`, `custom_field_value_history`, explicit `work_package_types` registry | ✗ | completeness/audit |

Already present in v2 (don't rebuild): `timesheets`, `okrLinkages`,
`customFields`/`customFieldValues`, `programIncrements`/`sprints`,
`dependencies`/`projectDependencies`, full SAFe hierarchy, EVM fields on projects.

## OKR ↔ Epic ↔ Task mapping (how it works in v2, and the one gap)

```
OKR (level: company|project|functional, functionalArea: vro/tmo/finops/…, parentOkrId)
  └─ KeyResult (targetValue, currentValue, unit, status, progress)
  └─ OkrLinkage (parentOkrId → childEntity[epic|feature|task], alignmentScore 0–1, confidence, inferredBy)
```
v2 already supports the cascade + AI-inferred alignment. **The one gap:**
`okr_linkages` records *that* an entity aligns, not *how much it contributes*. Add
`okr_entity_contributions` so agents can roll entity progress up into KR progress
(Σ entity.progress × contribution%). That's what makes the OKR dashboard reflect
real delivery, and it's the highest-value OKR addition.

## Connector sync flow (bidirectional)

```
OpenProject webhook  →  syncJob  →  OpenProjectClient (APIv3 fetch)
  →  fieldMappings + value-maps  →  OntologyDataProvider upsert (Project/Feature/Story/Task)
  →  timesheets aggregate → EVM  →  agents infer OKR linkages
  →  (write-back) agent verdicts → OpenProject project status + comments + follow-up WPs
```
Conflict policy: `syncJobs.conflictResolutionStrategy` (default `last_write_wins`;
`manual` for budget/status). `syncAuditLog` records mutations.

## Build order
1. Wire `openProjectClient.ts` → `OntologyDataProvider` (so the existing UI renders OpenProject data).
2. Add the 4 High-priority schema items (startDate, relations, releases, categories).
3. Add `okr_entity_contributions` + the agent roll-up.
4. Bidirectional write-back (status/comments/follow-ups) + webhook real-time.
