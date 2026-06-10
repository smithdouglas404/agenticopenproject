# 06 — Roadmap

Phased delivery from blueprint to a working 4-agent vertical slice and beyond. Each phase
is independently demoable.

## Decisions (locked 2026-06-09)

| Decision | Choice |
|---|---|
| **First vertical slice** | *Quick* — agent reasoning on **seeded** SAFe data (no ingestion pipeline yet) |
| **Graph sync** | **Realtime** — webhook-driven near-real-time projection, with a periodic reconciliation safety net |
| **Agent LLM** | **Anthropic Claude API** (Opus / Sonnet) |
| **First agent** | **Portfolio Insights & Risk** |
| **Graph store** | **FalkorDB + Graphiti** (property graph + bi-temporal memory) — see docs 05 / 08 |

This reshuffles the near-term path: rather than completing ingestion (Phase 2) before
agents (Phase 3), we cut a **thin "Quick slice"** that proves the spine end-to-end first.

### Quick slice — the next milestone
1. Seed SAFe data into OpenProject via `SeedSafeConfigurationService` + a small demo
   Portfolio→Value Stream→ART→Epic→Feature→Story tree.
2. Stand up **FalkorDB** + a **Python Graphiti** service (exposed over MCP).
3. **Projector:** OpenProject → graph, triggered by **webhooks** (realtime) plus a periodic
   reconcile.
4. **Portfolio Insights & Risk** agent (TypeScript, Claude) reasons over the graph and
   emits `AgentRecommendation`s.
5. Recommendations surface in the **Insights inbox** (already scaffolded in
   `modules/agentic_ppm`).

Ingestion connectors (Jira/Excel/etc., and the Methodology Mapper that normalizes them)
follow once the spine is proven.

## Phase 0 — Blueprint & ontology  ✅ (this deliverable)
- Vendored Smith Clarity ontology into `agentic-ppm/ontology/`.
- Architecture, SAFe reference model, OpenProject mapping, agent roster, data flow.
- DOSv2 refactor map (`07-refactor-from-dosv2.md`).

## Phase 1 — OpenProject as the SAFe substrate (`modules/agentic_ppm` skeleton)
**Goal:** OpenProject can *hold* the SAFe model and expose it to agents.
- Scaffold the Rails engine (`register`, `project_module`, `permission`, `menu`).
- Idempotent seeders: SAFe work-package **types** (Strategic Theme, Epic, Capability,
  Feature, Story, Enabler, Risk), **custom fields** (WSJF inputs, story points, epic
  fields, PI fields), **project templates** (Portfolio / Value Stream / ART).
- The **ontology binding registry** (OpenProject record ⇄ ontology IRI).
- Register the webhooks the runtime needs.
- *Demo:* create a Portfolio→Value Stream→ART→Epic→Feature→Story tree in OpenProject; show
  WSJF fields and PI versions.

## Phase 2 — Knowledge graph & realtime projection
**Goal:** OpenProject state is mirrored as an ontology-shaped, bi-temporal property graph.
- TS Agent Runtime skeleton: webhook receiver + APIv3 client + service-account auth.
- Projector: record → graph nodes/edges via the binding; bi-temporal stamping (Graphiti);
  idempotent upsert. Driven by webhooks (realtime) + periodic reconcile.
- Stand up **FalkorDB**; model the ontology schema; backfill from APIv3.
- Derived-insight pass: materialize the first derived signals (`OrphanedProject`,
  `CostAnomaly`) as graph nodes/labels for agents to query.
- *Demo:* change a Feature in OpenProject → see the graph update in near-real-time + a
  derived signal appear; run a cross-methodology Cypher/Graphiti roll-up.

## Phase 3 — First agents + Insights inbox (the vertical slice)
**Goal:** end-to-end autonomy for 4 agents.
- Agent Orchestrator (scheduler + A2A bus) + common agent contract.
- Implement **Portfolio Insights & Risk**, **Methodology Mapper**, **Flow & Delivery
  Optimizer**, **Planning & Dependency**.
- Notification Orchestrator (dedupe/prioritize/route).
- `AgentRecommendation` model + **Insights inbox UI** (global + project menu) with
  Accept/Dismiss/Snooze; write-back via module API.
- LLM (Claude) layer for explanation/prioritization/recommended-action drafting.
- *Demo:* a real recommendation appears in OpenProject, links to the work packages,
  explains itself, and is dismissible.

## Phase 4 — Learning & governance
- Feedback loop (accept/dismiss → agent memory; threshold/confidence tuning).
- Temporal/trend findings from scheduled cycles ("variance accelerating").
- Governance agent + policy-as-code (`k360:Policy`/`PolicyRule`); promote select low-risk
  recommendations to governed auto-apply.
- Admin view for `k360:AgentState` (cycle times, health).

## Phase 5 — Full agent roster & methodology breadth
- Remaining domains: VRO, TMO, FinOps, OKR, OCM (full).
- PMBOK/PRINCE2 dialect ingestion for mixed-methodology portfolios.
- Cross-domain composite findings at scale; portfolio-wide scenario planning.

## Sequencing notes
- Phases 1–3 are the critical path to a credible demo; 4–5 deepen autonomy and breadth.
- The ontology is stable input from Phase 0; changes to it are versioned and ripple
  through the binding (doc 03) and reasoner (doc 05).
- Reuse OpenProject features wherever they exist (see `07`) — build agent brains, not
  PPM plumbing.
