# Agentic PPM on OpenProject

An **Agentic Project & Portfolio Management (PPM)** platform built on top of
[OpenProject](https://www.openproject.org/). A set of autonomous agents continuously
read the portfolio, reason over a shared **knowledge-graph world model**, and write
back **typed, auditable recommendations and insights** — turning OpenProject from a
place where status is *recorded* into a system that *understands and reasons about*
the portfolio.

Three ideas anchor the design:

1. **OpenProject is the source of truth.** Every fact an agent acts on originates in,
   and every recommendation an agent produces lands back in, OpenProject. (This
   uses FalkorDB as the ontology / source of truth, replacing the original
   Smith Clarity deployment.)
2. **The Smith Clarity ontology is the agents' world model.** A formal W3C OWL/Turtle
   ontology with a framework-neutral PM "spine" (`pm:`) and dialects for **SAFe 6.0**,
   **PMBOK**, and **PRINCE2**, plus the **K360** module that models the agents
   themselves. SAFe 6.0 is the *well-architected reference model* every other
   methodology is mapped onto via bridging axioms.
3. **Agents are autonomous, learning, and accountable.** They run on a schedule and on
   events, keep memory, talk to each other (A2A), and every finding carries provenance,
   confidence, and a temporal audit trail.

---

## What's in this directory

```
agentic-ppm/
├── README.md                       ← you are here (index + quick start)
├── ontology/                       ← the Smith Clarity ontology (vendored, version-controlled)
│   ├── smith-clarity-mega-ontology.ttl
│   ├── modules/{core,safe,pmbok,prince2,k360,bridging}.ttl
│   └── README.md                   ← ontology authors' own guide
└── docs/
    ├── 00-vision-and-principles.md     Why this exists; the non-negotiables
    ├── 01-architecture-blueprint.md    System architecture, components, boundaries
    ├── 02-safe6-ontology-model.md      SAFe 6.0 as the reference model + mapping methodologies
    ├── 03-openproject-mapping.md       Ontology ⇄ OpenProject data-model mapping (the crux)
    ├── 04-agent-roster.md              The 9 agent domains; first-iteration agents
    ├── 05-data-flow-and-knowledge-graph.md   Webhooks → graph → reasoning → write-back
    ├── 06-roadmap.md                   Phased delivery plan
    ├── 07-refactor-from-dosv2.md       Lifting the Kyndryl-365 DOSv2 app onto OpenProject
    └── 08-product-and-saas-architecture.md   v2 decisions: one product on OpenProject,
                                              SaaS/tenancy, FalkorDB+Graphiti, HITL
```

> **Read `08` first for current decisions.** It captures the consolidated v2 direction
> (one product on top of OpenProject, ontology as normalization layer, graph as source of
> insight & truth, FalkorDB+Graphiti, membership-based tenancy, HITL traceability) and
> supersedes earlier open questions in docs 00–07 where they differ.

## Read in this order

If you read nothing else, read **`docs/01-architecture-blueprint.md`** and
**`docs/03-openproject-mapping.md`** — together they define *what we're building* and
*how it binds to OpenProject*.

## Status

**Phase 0 — Blueprint.** This is the foundational design + the vendored ontology. No
runtime code yet. The blueprint defines two build targets:

- a **native OpenProject Rails module** (`modules/agentic_ppm`) that owns the ontology
  binding, the recommendation/insight inbox UI, and the agent-facing API; and
- a **TypeScript/Node agent runtime** that hosts the autonomous agents.

The agent runtime is not greenfield: it is the existing
[Kyndryl-365 DOSv2 framework](https://github.com/smithdouglas404/Kyndral-365-Agentic-VRO-Framework-DOSv2)
refactored so OpenProject provides the data tier, UI, auth, and PPM features it currently
reimplements. See `docs/07-refactor-from-dosv2.md`.

See `docs/06-roadmap.md` for sequencing.
