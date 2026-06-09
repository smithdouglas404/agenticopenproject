# 07 — Refactoring the Kyndryl-365 DOSv2 Framework onto OpenProject

The existing implementation —
[`Kyndral-365-Agentic-VRO-Framework-DOSv2`](https://github.com/smithdouglas404/Kyndral-365-Agentic-VRO-Framework-DOSv2)
— is a TypeScript monorepo that already contains the agent system the ontology was built
for. The goal of this project is **not** to rebuild it, but to **lift the agent brains out
and let OpenProject provide everything OpenProject already does well.**

## 1. What DOSv2 is today

| Area | DOSv2 implementation |
|---|---|
| Language | TypeScript (~98%), some Python/PLpgSQL/Cypher |
| Layout | `server/` (backend), `client/` (frontend UI), `shared/` (common code) |
| Data | PostgreSQL + **Drizzle ORM**; **Neo4j** graph (Cypher) |
| Agents | VRO / TMO / PMO (and more) orchestrated via **MCP** (Model Context Protocol) |
| Memory | **Mem0** for cross-agent memory |
| Workflows | **Langflow** for AI workflow automation |
| Deploy | Docker (`Dockerfile.production`, `docker-compose.yml`), **Kubernetes** (`k8s/`), PM2 |
| Other | `migrations/`, `scripts/`, `tests/load/`, `docs/`, `archive/` |

## 2. The refactor principle

> **OpenProject becomes the source of truth and the user interface.** Anything in DOSv2
> that *stores or presents portfolio/project data* is dropped in favor of OpenProject.
> Anything that *reasons* (the agents, the graph world-model, memory, orchestration) is
> kept and re-pointed at OpenProject.

This collapses DOSv2 from "a whole PPM product" into "the agent runtime" in the blueprint
(`01-architecture-blueprint.md` §2.3).

## 3. Keep / Drop / Replace map

### ✅ KEEP (becomes the Agent Runtime)
| DOSv2 piece | Why it stays | Where it lands |
|---|---|---|
| `server/` agent logic (VRO/TMO/PMO + others) | The actual value — the reasoning | Agent Runtime, the 9 domains (doc 04) |
| **MCP** orchestration | Agent tool/skill wiring | Agent Orchestrator + A2A bus |
| **Neo4j** graph *(or swap to a triple store)* | The world model | Knowledge Graph (doc 05) — see §5 |
| **Mem0** memory | `k360:AgentMemory` / learning | Agent memory layer |
| `shared/` types relevant to agents/ontology | Reuse | Shared lib (re-pointed to ontology IRIs) |
| `docs/` MCP & agent integration guides | Still valid | Fold into `agentic-ppm/docs` |

### 🔁 REPLACE (OpenProject already provides this)
| DOSv2 piece | Replaced by OpenProject feature |
|---|---|
| PostgreSQL app tables for projects/programs/tasks/milestones/resources (Drizzle schema for portfolio data) | OpenProject **Projects + Work Packages + Versions + Relations + Custom Fields** (the source of truth) |
| `client/` frontend (dashboards, project/task views, gantt, boards) | OpenProject **UI**: work packages, **Gantt**, **Boards**, **Team planner**, **Dashboards/Overviews**, **Calendar** modules |
| Cost/budget tracking tables & views | OpenProject **Budgets/Costs** + **Time tracking** modules |
| User/role/permission management | OpenProject **users, groups, roles, permissions** (agents authenticate via a scoped service account) |
| Notifications infrastructure (delivery) | OpenProject **notifications** + the **Insights inbox** in `modules/agentic_ppm` |
| Reporting / status views | OpenProject **Reporting** + **Project queries/views**; agent findings surfaced in-app |
| `migrations/` for portfolio-data schema | OpenProject migrations + `modules/agentic_ppm` seeders (types/fields) |
| Auth/session handling | OpenProject **OAuth2 / API tokens** |

### ❌ DROP (no longer needed)
| DOSv2 piece | Reason |
|---|---|
| Bespoke portfolio CRUD APIs | Superseded by OpenProject **APIv3** |
| Duplicate domain models that mirror projects/tasks | OpenProject is the SoT; the KG is a projection |
| `archive/` legacy | Out of scope |
| Standalone deploy assets that assume DOSv2 owns the data tier | Replaced by "OpenProject + agent-runtime sidecar" topology |

### ⚖️ EVALUATE (decide per cost/benefit)
| DOSv2 piece | Decision factors |
|---|---|
| **Langflow** workflows | Keep if visual agent-flow authoring is valued; otherwise the Orchestrator + Claude SDK may suffice |
| **Neo4j vs. triple store** | Neo4j is property-graph (Cypher); the ontology is OWL/Turtle/SPARQL. See §5 |
| K8s manifests | Reuse for the runtime; the data-tier portions for app Postgres are dropped |
| Load tests | Re-target at the runtime + module API, not at replaced data APIs |

## 4. Concrete migration steps

1. **Carve the runtime out of DOSv2.** Extract `server/` agents + MCP + Mem0 + graph into
   a standalone **Agent Runtime** service (the TS/Node service in the blueprint). Strip its
   dependency on the DOSv2 Postgres portfolio schema.
2. **Delete the portfolio data tier.** Remove Drizzle models/migrations that store
   projects/tasks/etc.; the runtime now reads those from OpenProject APIv3.
3. **Retire `client/`.** Its job is done by OpenProject's UI + the `agentic_ppm` Insights
   inbox. Salvage any genuinely novel visualization as an OpenProject module view only if
   OpenProject lacks it.
4. **Re-point the world model.** The projector (doc 05) populates the graph from
   OpenProject instead of from DOSv2's own DB. Agent code now resolves entities by
   ontology IRI ⇄ OpenProject id (binding, doc 03).
5. **Re-wire write-back.** Agent findings POST to the `modules/agentic_ppm` API →
   OpenProject, instead of writing to DOSv2 tables/UI.
6. **Auth.** Replace DOSv2 auth with an OpenProject service account (scoped OAuth2);
   webhook signature verification on ingest.
7. **Deploy topology.** From "DOSv2 owns everything" to **OpenProject (SoT + UI + module)
   ⟷ Agent Runtime sidecar ⟷ triple store**. Keep K8s; drop app-Postgres-owns-portfolio.

## 5. Graph store: keep Neo4j or move to a triple store?

The ontology is native **OWL/Turtle + SPARQL + OWL reasoning** (derived classes via
`rdfs:subClassOf*`, `owl:equivalentClass`). Two paths:

- **Triple store (recommended for fidelity):** Oxigraph / Jena Fuseki / Stardog — loads
  `smith-clarity-mega-ontology.ttl` directly, runs the equivalence/subclass reasoning the
  bridging axioms depend on, and the README's SPARQL patterns work as-is.
- **Keep Neo4j (recommended for least churn):** keep DOSv2's existing graph and encode the
  ontology as a property-graph schema; lose native OWL reasoning (re-implement
  subclass/equivalence traversal in Cypher) but reuse all existing wiring and Mem0
  integration.

A pragmatic hybrid: **Neo4j for the operational/temporal graph + agent memory**, and load
the **ontology TBox into a lightweight triple store** for the reasoning/equivalence
queries. Pick during Phase 2 based on how much OWL inference the first agents actually
need — start simple, add reasoning depth when a finding requires it.

## 6. Net effect

DOSv2 shrinks to its differentiator — **the agents and their world model** — and inherits a
mature, open-source PPM platform (data model, UI, auth, permissions, gantt, boards,
costs, reporting, notifications) for free. Less code to maintain, a real source of truth,
and the agents land their insights where people already work.
