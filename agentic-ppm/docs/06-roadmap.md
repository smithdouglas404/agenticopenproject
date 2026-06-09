# 06 — Roadmap

Phased delivery from blueprint to a working 4-agent vertical slice and beyond. Each phase
is independently demoable.

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

## Phase 2 — Ingest & knowledge graph
**Goal:** OpenProject state is mirrored as an ontology-shaped, temporal graph.
- TS Agent Runtime skeleton: webhook receiver + APIv3 client + service-account auth.
- Projector: record → triples via the binding; temporal stamping; idempotent upsert.
- Stand up the triple store; load the ontology TBox; backfill ABox from APIv3.
- Reasoner: load OWL, materialize the first derived classes (`OrphanedProject`,
  `CostAnomaly`).
- *Demo:* change a Feature in OpenProject → see the triple update + a derived class appear;
  run a cross-methodology SPARQL roll-up.

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
