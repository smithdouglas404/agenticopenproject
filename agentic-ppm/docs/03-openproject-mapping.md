# 03 — Ontology ⇄ OpenProject Data-Model Mapping

This is the crux: how the Smith Clarity ontology binds to OpenProject's real data model so
OpenProject can be the source of truth. It extends the bridging module's "external tool
aliases" with an **OpenProject dialect**.

## 1. OpenProject's data model (what we have to work with)

From the OpenProject codebase (`app/models/`, `lib/api/v3/`):

- **`Project`** — hierarchical (self-nesting `parent_id`), has many `work_packages`,
  `versions`, `types`, `members`, `budgets`, `phases` (`Project::Phase`). Projects can
  carry **project custom fields**.
- **`WorkPackage`** — the universal work item. Has a **`Type`** (configurable: Task, Bug,
  Feature, Epic, Milestone, Phase…), a **`Status`**, **parent/child hierarchy**,
  **custom fields**, `assigned_to`, `version`, `estimated_hours`, `done_ratio`,
  `start_date`, `due_date`.
- **`Relation`** — typed links between work packages: `relates`, `precedes`, `follows`,
  `blocks`, `blocked`, `duplicates`, `includes`, `partof`, `requires`. (Parent/child is
  modeled separately via the hierarchy.)
- **`Version`** — used for releases/sprints; work packages belong to a version.
- **`Type`, `Status`, `CustomField`** — fully configurable; this is our main extension
  surface.
- **`TimeEntry`, `Budget`/Costs** — actuals for EVM-style metrics.
- **APIv3** (Grape) + **Webhooks module** (outgoing events on work package / project /
  comment / time entry / attachment create+update) — the integration nervous system.

## 2. The mapping (ontology IRI ⇄ OpenProject)

### 2.1 Structure / hierarchy

| Ontology class | OpenProject representation | Notes |
|---|---|---|
| `safe:Portfolio` / `pm:Portfolio` | **Project** with custom field `op_safe_level = Portfolio` | top of a project tree |
| `safe:ValueStream` / `pm:Program` | **Project** (`op_safe_level = ValueStream`), child of Portfolio project | |
| `safe:ART` | **Project** (`op_safe_level = ART`) or a Team grouping, child of Value Stream | |
| `safe:Team` / `pm:Team` | **Group / project membership** + custom field | OpenProject groups & members |
| `safe:StrategicTheme` | **WorkPackage type** `Strategic Theme` at portfolio project | |
| `safe:Epic` / `pm:Epic` | **WorkPackage type** `Epic` | `epicType`, lean business case → custom fields |
| `safe:Capability` | **WorkPackage type** `Capability` | spans ARTs |
| `safe:Feature` / `pm:Feature` | **WorkPackage type** `Feature` | WSJF fields attached here |
| `safe:Story` / `pm:Story` | **WorkPackage type** `User Story` | story points |
| `safe:Enabler` | **WorkPackage type** `Enabler` | architectural runway |
| `safe:ProgramIncrement` (PI) | **Version** (or `Project::Phase`) tagged `kind=PI` | timebox |
| `safe:Sprint` | **Version** tagged `kind=Sprint` | iteration |
| `pm:Milestone` | **WorkPackage type** `Milestone` (built-in) | |
| `pm:Risk` | **WorkPackage type** `Risk` (new) | or a Risk custom object |
| `pm:Issue` | **WorkPackage type** `Bug`/`Issue` | |
| `pm:Dependency` | **Relation** (`precedes`/`follows`/`blocks`/`requires`) | not a record — a link |

> Work-package **parent/child** expresses the Epic→Capability→Feature→Story decomposition
> (`safe:decomposesTo`). Work-package **Relations** express `pm:dependsOn` /
> `pm:Dependency`.

### 2.2 Properties (datatype) — ontology property ⇄ OpenProject field

| Ontology property | OpenProject field |
|---|---|
| `pm:taskName` / `pm:projectName` | `subject` / project `name` |
| `pm:taskStatus` / `pm:projectStatus` | `Status` |
| `pm:taskDescription` | `description` |
| `pm:assignee` / `pm:isAssignedTo` | `assigned_to` |
| `pm:hasStartDate` / `pm:hasDueDate` | `start_date` / `due_date` |
| `pm:effortHours` | `estimated_hours` |
| `pm:completionPercentage` | `done_ratio` |
| `pm:hasBudget` / `pm:budgetSpent` | Costs/Budget module + TimeEntry roll-up |
| `pm:storyPoints` | **custom field** `Story points` |
| `safe:wsjfScore`, `businessValue`, `timeCriticality`, `riskReduction`, `jobSize` | **custom fields** on Feature type (WSJF computed) |
| `safe:epicType`, `leanBusinessCase`, `mvpStatement`, `hypothesisStatement` | **custom fields** on Epic type |
| `safe:piObjectives`, `plannedVelocity`, `actualVelocity` | **custom fields** on the PI Version |
| `pm:cpiValue` / `pm:spiValue` | **derived** (computed by FinOps/PMO agent from costs + schedule), stored as read-only custom fields |

### 2.3 K360 agent objects ⇄ OpenProject

| K360 class | OpenProject representation |
|---|---|
| `k360:Objective` / `k360:KeyResult` (OKRs) | **WorkPackage types** `Objective` / `Key Result`, linked to portfolio |
| `k360:AgentFinding` / `k360:Intervention` | **`AgentRecommendation`** model in `modules/agentic_ppm` (surfaced in the Insights inbox); optionally mirrored as a comment/flag on the related work package |
| `k360:ComplianceCheckpoint` | **WorkPackage type** `Governance Checkpoint` or project phase gate |
| `k360:Budget` / `k360:CostRecord` | Costs/Budget module + TimeEntry |
| `k360:Agent`, `AgentState`, `AgentMemory`, `A2AMessage` | **Agent Runtime** (not OpenProject) — operational state |

## 3. How the binding is implemented

`modules/agentic_ppm` holds a declarative **binding registry**, e.g.:

```ruby
# illustrative
AgenticPpm::Ontology.bind do
  klass "safe:Feature",  to: work_package_type("Feature")
  klass "safe:Epic",     to: work_package_type("Epic")
  klass "safe:Portfolio", to: project_level("Portfolio")
  prop  "safe:wsjfScore", to: custom_field("wsjf_score")
  prop  "pm:taskStatus",  to: :status
  prop  "pm:hasDueDate",  to: :due_date
end
```

- **Forward** (OpenProject → graph): the projector asks the binding "what ontology
  class/props does this work package map to?" and emits FalkorDB/Graphiti nodes & edges
  (ontology IRIs become node labels/types).
- **Reverse** (agent finding → OpenProject): a `k360:AgentFinding` referencing
  `safe:Feature/123` resolves back to `WorkPackage#123` to attach the recommendation.

The binding is the **single place** the OpenProject⇄ontology translation lives, keeping
the Rails module and the TS runtime decoupled (both speak ontology IRIs).

## 4. Configuration vs. seeding

`modules/agentic_ppm` ships idempotent seeders that, on install:
1. Create SAFe work-package **types** and assign them sensible default **workflows**.
2. Create the WSJF / Epic / PI **custom fields** and attach them to the right types.
3. Create project **templates** for Portfolio / Value Stream / ART with the right modules
   enabled.
4. Register the **webhooks** the runtime consumes.

All re-runnable; nothing destructive. Admins can opt types/fields in per project.

## 5. Why this works

OpenProject's *configurable types + custom fields + project hierarchy + typed relations*
are expressive enough to represent the full SAFe hierarchy and the WSJF/flow attributes
**without forking the core model**. The agents never need a competing store — they read
this structure, reason, and write recommendations back to it.
