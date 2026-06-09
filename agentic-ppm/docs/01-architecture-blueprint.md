# 01 — Architecture Blueprint

## 1. The big picture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              OpenProject (Rails)                               │
│                          ── SOURCE OF TRUTH ──                                 │
│                                                                                │
│  Core domain: Projects · Work Packages · Types · Status · Versions · Relations │
│               · Custom Fields · Time Entries · Budgets · Members                │
│                                                                                │
│  ┌──────────────────────────────────────────────────────────────────────────┐│
│  │  modules/agentic_ppm   (NEW native Rails engine)                          ││
│  │  • SAFe type/field seed (Portfolio…Enabler, WSJF, PI, …)                  ││
│  │  • Ontology binding (maps OP records ⇄ ontology IRIs)                     ││
│  │  • Insights & Recommendations inbox UI (project + global menu)            ││
│  │  • Agent-facing API (read context, post AgentFinding, feedback)           ││
│  │  • Webhook registration + signed event relay                              ││
│  └──────────────────────────────────────────────────────────────────────────┘│
└───────────────┬──────────────────────────────────────────────▲────────────────┘
                │ webhooks (work_package/project/comment/…)     │ APIv3 + module API
                │ + APIv3 reads                                 │ (write-back: findings,
                ▼                                               │  recommendations)
┌──────────────────────────────────────────────────────────────┴────────────────┐
│                      Agent Runtime  (TypeScript / Node)                         │
│                                                                                │
│  ┌────────────┐   ┌──────────────────────────┐   ┌──────────────────────────┐  │
│  │  Ingest /  │──▶│   Knowledge Graph (KG)   │◀──│   Reasoner / OWL + rules │  │
│  │  Projector │   │  triple store, world     │   │  (derives OrphanedProject │  │
│  │ (webhooks  │   │  model = ontology + data │   │   CostAnomaly, …)         │  │
│  │  + polling)│   └──────────────────────────┘   └──────────────────────────┘  │
│  └────────────┘              ▲     │                                            │
│                              │     ▼                                            │
│   ┌──────────────────────────┴───────────────────────────────────────────┐    │
│   │                    Agent Orchestrator (scheduler + A2A bus)           │    │
│   │   VRO · StrategicPMO · TMO · FinOps · OKR · Governance · Planning ·   │    │
│   │   OCM · Notification    (each = world-model read → reason → finding)  │    │
│   └──────────────────────────────────────────────────────────────────────┘    │
│                              │                                                  │
│                              ▼  LLM calls (reasoning, summarization, NL)        │
│                     ┌─────────────────────┐                                    │
│                     │   Claude (Anthropic) │  via Agent SDK / API              │
│                     └─────────────────────┘                                    │
└────────────────────────────────────────────────────────────────────────────────┘
```

## 2. Components and responsibilities

### 2.1 OpenProject core — *source of truth*
Unchanged OpenProject. We add **types, statuses, custom fields, and project structure**
that express the SAFe model (see `03-openproject-mapping.md`), but we do **not** fork the
core domain model. Everything an agent needs to know is reachable via APIv3 + the module
API; everything an agent proposes is written back here.

### 2.2 `modules/agentic_ppm` — native Rails engine (the in-app surface)
A first-class OpenProject module (Rails engine), following the same DSL as
`modules/boards`, `modules/webhooks`, etc. (`register`, `project_module`, `permission`,
`menu`). Responsibilities:

- **SAFe seed & configuration.** Idempotent seeders that create the SAFe work-package
  **types** (Strategic Theme, Epic, Capability, Feature, Story, Enabler), the **custom
  fields** (WSJF inputs, PI, business value, …), and **project templates** for
  Portfolio / Value Stream / ART.
- **Ontology binding.** A small registry that maps OpenProject records to ontology IRIs
  and back (e.g. `WorkPackage(type=Feature)` ⇄ `safe:Feature`). This is the
  authoritative translation layer; the agent runtime consumes it.
- **Insights & Recommendations inbox.** The human-facing payoff: a project-level and
  global menu entry showing agent findings — ranked, explained, with links to the
  work packages they concern, and **Accept / Dismiss / Snooze** actions. Backed by an
  `AgentRecommendation` AR model (a thin OpenProject-side persistence of
  `k360:AgentFinding` / `k360:Intervention`).
- **Agent-facing API.** Authenticated endpoints (OAuth2 / API token, scoped permissions)
  for the runtime to (a) pull enriched context and (b) POST findings and feedback. This
  keeps agent write-back governed by OpenProject's own permission system.
- **Event relay.** Registers/normalizes the OpenProject **webhooks** the runtime needs,
  with signature verification.

> **Why native + external split?** The Rails module gives us tight UI integration,
> OpenProject's auth/permissions, and a clean place for the ontology binding — while the
> reasoning "brains" live in a TypeScript runtime with the richer agent/LLM ecosystem.
> This matches the chosen approach: *native Rails engine for integration, TS/Node for
> the agents.*

### 2.3 Agent Runtime — TypeScript / Node (the brains)
A standalone service (deployable beside OpenProject) hosting:

- **Ingest / Projector.** Receives OpenProject webhooks and polls APIv3 for backfill;
  translates records into ontology-shaped triples via the binding from §2.2 and upserts
  them into the KG with temporal stamps.
- **Knowledge Graph (KG).** A triple store (e.g. Oxigraph / Apache Jena Fuseki / Stardog)
  holding the **ontology (TBox)** + **projected portfolio facts (ABox)** + **derived
  facts**. This is the world model.
- **Reasoner.** Loads `smith-clarity-mega-ontology.ttl`, runs OWL reasoning + rule
  evaluation (SHACL/SWRL-style or GoRules decision tables per `k360:PolicyRule`) to
  materialize derived classes (`OrphanedProject`, `CostAnomaly`, …).
- **Agent Orchestrator.** Scheduler (cron-style reasoning cycles) + event triggers + the
  **A2A bus** (`k360:A2AMessage`). Each agent is a module implementing a common contract:
  `observe(world) → reason() → emit(findings[])`.
- **LLM layer.** Claude (via the Anthropic API / Agent SDK) for natural-language
  reasoning, summarization of findings, hypothesis generation, and explanation text.
  Deterministic graph rules do the *detection*; the LLM does the *explanation,
  prioritization narrative, and recommended-action drafting*.
- **Memory & learning.** `k360:AgentMemory` persistence; recommendation feedback
  (accept/dismiss) loop captured for tuning.

### 2.4 Claude / LLM
Used for: turning a derived finding into a human-readable, ranked recommendation;
drafting suggested actions; the Methodology Mapper's classification of ambiguous
external work items; and cross-domain "connect the dots" narratives. Not used as the
system of record and not the sole detector — graph rules remain the backbone for
auditability.

## 3. Boundaries & data ownership

| Concern | Owner | Notes |
|---|---|---|
| Portfolio facts (projects, WP, budgets, time) | **OpenProject** | Single source of truth |
| SAFe type/field schema | `modules/agentic_ppm` seeders | Expressed in OpenProject |
| Ontology (TBox) | `agentic-ppm/ontology/*.ttl` | Versioned in repo, loaded by runtime |
| Projected + derived facts (ABox) | Agent Runtime KG | Rebuildable from OpenProject; **not** a source of truth |
| Recommendations / findings | Written to **OpenProject** (via module API), cached in KG | Human-governable |
| Agent memory / A2A | Agent Runtime | Operational state |

**Rebuildability rule:** the KG must be fully reconstructable by replaying OpenProject.
If the KG is lost, no portfolio truth is lost.

## 4. Key architectural decisions (and rationale)

1. **Native Rails module + external TS runtime (hybrid-in-practice).**
   Tightest in-app UX and OpenProject-native auth, with the agent ecosystem where it's
   strongest. Chosen over pure-Ruby (weak AI/ML ecosystem) and pure-external (loses
   in-app integration and permission reuse).
2. **OpenProject as SoT; KG as projection.** Avoids a competing system of record;
   guarantees auditability lives where governance already lives.
3. **Ontology as the contract between Rails and TS.** Both sides agree on ontology IRIs;
   neither needs to know the other's internal models beyond the binding table.
4. **Rules detect, LLM explains.** Keeps detection deterministic/auditable while still
   getting natural-language reasoning and prioritization.
5. **Propose-then-approve write-back.** Default safety posture; specific low-risk actions
   can later be promoted to auto-apply under `k360:Policy` governance.

## 5. Cross-cutting concerns

- **Security/auth:** Agent runtime authenticates to OpenProject with a dedicated service
  account + scoped OAuth2; webhook payloads are signature-verified; module API enforces
  OpenProject permissions so an agent can never exceed its granted scope.
- **Observability:** every agent cycle, finding, and write-back is logged with
  correlation IDs; `k360:AgentState.lastCycleTime` surfaced in an admin view.
- **Idempotency:** projector upserts are keyed by OpenProject IDs; findings are
  deduplicated (Notification Orchestrator) so re-runs don't spam the inbox.
- **Temporality:** every projected fact and finding carries `valid_from`/`valid_to` +
  version for time-travel queries and trend detection.

See `05-data-flow-and-knowledge-graph.md` for the end-to-end event lifecycle.
