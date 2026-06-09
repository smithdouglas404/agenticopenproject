# 05 — Data Flow & the Knowledge Graph

## 1. End-to-end lifecycle

```
(1) Change in OpenProject
     e.g. a Feature's status/WSJF changes, a dependency is added, time is logged
        │
        ▼
(2) OpenProject Webhook fires  ──────────────▶  Agent Runtime: Ingest endpoint
     (work_package/project/comment/time_entry, create+update; signature-verified)
        │
        ▼
(3) Projector
     - resolves the OpenProject record via the binding registry (doc 03)
     - emits ontology-shaped RDF triples (safe:/pm:/k360:)
     - stamps temporal metadata (valid_from, version, created_by)
     - upserts into the Knowledge Graph (idempotent, keyed by OP id)
        │
        ▼
(4) Reasoner
     - TBox = smith-clarity-mega-ontology.ttl (classes, subClassOf, equivalences)
     - ABox = projected portfolio facts
     - runs OWL reasoning + rules → materializes derived classes
       (OrphanedProject, CostAnomaly, TransformationFatigue, ComplianceViolation…)
        │
        ▼
(5) Agent Orchestrator
     - triggers affected agents (event-driven) and/or scheduled reasoning cycle
     - each agent: observe(KGView) → reason() → emit(findings)
     - agents exchange A2A messages to compose cross-domain findings
        │
        ▼
(6) Notification Orchestrator
     - dedupes against open findings, scores priority, applies NotificationRules
     - escalation paths for high-severity items
        │
        ▼
(7) Write-back  ──────────────▶  modules/agentic_ppm API (OpenProject)
     - persists AgentRecommendation (mirror of k360:AgentFinding)
     - links to the exact work packages/projects concerned
     - default posture: PROPOSE (human Accept/Dismiss/Snooze)
        │
        ▼
(8) Insights inbox (OpenProject UI)
     - portfolio manager sees ranked, explained recommendations
     - feedback (accept/dismiss) → written back → agent memory/learning
```

Two trigger modes run in parallel:
- **Event-driven** (steps 2–8) for low-latency reaction to changes.
- **Scheduled cycles** — periodic full-portfolio reasoning (e.g. nightly) for trend/
  temporal findings ("variance accelerating") that no single event reveals.

## 2. The knowledge graph (world model)

### Composition
- **TBox (schema):** the vendored ontology (`agentic-ppm/ontology/*.ttl`) — loaded once,
  versioned in the repo.
- **ABox (facts):** projected from OpenProject (rebuildable at any time).
- **Derived facts:** materialized by the reasoner; never authoritative, always
  recomputable.

### Store
**Decided (v2 — see `08-product-and-saas-architecture.md`): FalkorDB + Graphiti.**
FalkorDB is the low-latency property-graph store (Cypher, built-in vector index,
multi-graph for per-tenant isolation); Graphiti provides the bi-temporal knowledge-graph
layer and agent memory on top, with incremental real-time updates and GraphRAG retrieval.
The ontology is loaded as the **schema** (Graphiti custom entity/edge types) rather than
run through an OWL reasoner; equivalence and derived-class logic is implemented in
Cypher + agent rules. The **rebuildability rule** still holds: the graph is a projection
of OpenProject and can be rebuilt from it.

### Why a graph (not just SQL)
Cross-domain questions span risk, budget, schedule, OKRs, and readiness simultaneously.
In a graph these are one connected structure, so a single SPARQL query answers
*"which strategic objectives are funded by over-budget projects that also have low adoption
readiness?"* — impossible when each domain sits in its own table/tool.

Example (from the ontology's own query patterns) — find all "tasks" regardless of source
methodology:
```sparql
SELECT ?task WHERE { ?task a ?type . ?type rdfs:subClassOf* pm:Task . }
# returns SAFe Stories, PMBOK Activities, PRINCE2 Activities, OpenProject work packages…
```

## 3. Temporality & learning

Every projected fact and every finding is **temporal** (`valid_from`/`valid_to`,
`version`, `created_by`). This enables:
- **Time-travel queries:** "what did the portfolio look like at PI-3 start?"
- **Leading indicators:** trend detection over versions, not just current state.
- **Audit:** full provenance for every value and every recommendation — the answer to
  "who changed this budget and when" lives in the graph, mirrored to OpenProject's own
  journals.

## 4. Consistency & failure modes

- **Idempotency:** projector upserts keyed by OpenProject IDs; replays are safe.
- **Backfill:** on cold start (or KG loss), the projector pages APIv3 to rebuild the ABox.
- **Webhook gaps:** scheduled reconciliation polls APIv3 deltas to catch missed events.
- **No competing truth:** if KG and OpenProject disagree, OpenProject wins; the KG is
  recomputed.
- **Write-back safety:** recommendations are proposals by default; only policy-approved,
  low-risk action types may auto-apply, always logged and reversible.
