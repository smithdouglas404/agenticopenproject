# 08 — Product Shape, SaaS & Experience (v2 — supersedes earlier open questions)

This document records the decisions made after the Phase-0 blueprint, based on direct
direction. Where it conflicts with docs 00–07, **this document wins** and those docs are
amended to point here.

## 1. It is ONE product, built on top of OpenProject

The polished, agent-driven **living dashboard and OpenProject are one thing** — not a
separate app competing with OpenProject. We build a **new, polished front end** that
becomes the primary face, and we **layer it on top of OpenProject's existing UIs** for the
standard and deep PPM work (work packages, Gantt, boards, time, costs). Users live in the
new front end and **drill through into the embedded OpenProject UIs** when they need deep
PPM detail. So:

- people who don't already have a project tool can use *our* interface as their PPM tool;
- OpenProject is the embedded **PPM engine + system of record/storage** underneath, and
  its existing UIs remain available (wrapped) for deep PPM tasks;
- the agentic insight layer is part of the same product, not a bolt-on.

> Mental model: **OpenProject is the engine, the system of record, and the deep-PPM UI.
> Our new polished front end is the face on top of it. The knowledge graph is the brain.**
> All one product.

## 2. The three roles — who owns what

| Layer | Role | Technology |
|---|---|---|
| **Inputs** (other PM tools, Excel, ticketing, manual entry) | Raw signals to normalize | Jira/Azure/ServiceNow/Excel/CSV/API |
| **Ontology** | Universal **mapping / normalization** layer everything flows through | Smith Clarity ontology (`agentic-ppm/ontology/`) |
| **OpenProject** | **System of record / canonical storage** | OpenProject (projects, work packages, types, custom fields, versions, relations) |
| **Knowledge graph** | **Source of insight & truth** — the relationship model agents reason over | **FalkorDB + Graphiti** (temporal KG) |
| **Agents** | Learn from the graph; emit alerts/notifications/recommendations | TS agents + Python Graphiti service (via MCP) |
| **HITL interface** | Where humans receive and act on agent output, with traceability | Polished dashboard on top of OpenProject |

## 3. Data flow (the corrected, authoritative version)

```
                      ┌─────────────────────────────────────────────┐
  External inputs ───▶│  ONTOLOGY mapping / normalization layer      │
  (Jira, Azure,       │  every input is mapped to ontology classes   │
   Excel, tickets,    │  (safe:/pm:/k360:) regardless of source      │
   manual entry)      └───────────────────────┬─────────────────────┘
                                               │  persisted into the
                                               ▼  RIGHT OpenProject construct
                      ┌─────────────────────────────────────────────┐
                      │  OPENPROJECT  — system of record / storage   │
                      │  projects · work packages · types · CFs ·    │
                      │  versions · relations · costs · time         │
                      └───────────────────────┬─────────────────────┘
                                               │  continuously projected
                                               ▼  (webhooks + APIv3)
                      ┌─────────────────────────────────────────────┐
                      │  KNOWLEDGE GRAPH (FalkorDB + Graphiti)       │
                      │  the relationship model = SOURCE OF INSIGHT  │
                      │  & TRUTH; temporal, bi-temporal, agent memory│
                      └───────────────────────┬─────────────────────┘
                                               │  agents learn & reason
                                               ▼
                      ┌─────────────────────────────────────────────┐
                      │  AGENTS  → alerts · notifications ·          │
                      │  recommendations · insights                  │
                      └───────────────────────┬─────────────────────┘
                                               ▼  with full traceability
                      ┌─────────────────────────────────────────────┐
                      │  HITL INTERFACE (polished, on top of OP)     │
                      │  who/why/confidence/source-records/timestamp │
                      │  → Accept / Dismiss / Snooze / Escalate      │
                      └─────────────────────────────────────────────┘
```

Two directions matter and both are intended:
1. **Inputs → ontology → OpenProject:** anything (Excel, tickets, other PM tools) is
   normalized through the ontology and **stored in the appropriate OpenProject system**.
   OpenProject stays the canonical store.
2. **OpenProject → knowledge graph:** OpenProject is *mapped into* the graph so we get
   insight from a model that has an **underlying relationship structure** — which a
   flat tool cannot give you.

## 4. Source of truth — reconciled

- **OpenProject = operational system of record** (the durable, editable PPM data).
- **Knowledge graph = source of insight & truth** (the unified, temporal, reasoned-over
  relationship model the agents and dashboard read).

These are not in conflict: OpenProject stores *what is*, the graph understands *what it
means and how it relates over time*. The graph is kept in sync from OpenProject; if lost,
it is rebuilt from OpenProject.

## 5. HITL & traceability (non-negotiable)

Every agent output reaching a human carries:
- **source agent** (which of the 9 domains),
- **why** (the rule/signal/derived class that fired, e.g. `OrphanedProject`),
- **confidence**,
- **source records** (links to the exact OpenProject work packages/projects),
- **timestamp + temporal validity** (when it became true).

Humans **Accept / Dismiss / Snooze / Escalate**; the outcome is written back and feeds
agent learning. Agents propose; humans (or governed policies) decide.

## 6. SaaS model & authentication — separate identity plane

- A **dedicated identity / tenant control plane** owns registration, login, and tenant
  provisioning, and **fronts both the new front end and OpenProject via SSO** (e.g.
  Auth0/Clerk/Keycloak + a tenant manager). Users authenticate once and are signed into
  both the polished front end and the embedded OpenProject UIs.
- OpenProject is configured as an **SSO/OIDC client** of this identity plane (OpenProject
  supports OIDC/SAML), so the embedded deep-PPM UIs honor the same session and the
  agent runtime authenticates as a scoped service principal.
- The existing DOSv2 login flow **informs** this design but is not the authority; the
  separate identity plane is.

## 7. Tenancy — membership-driven

A tenant is created based on **how the member joins** (Company vs. Individual), and the
membership type maps to an **isolation tier (hybrid by tier)**:

| Membership | Tier | Isolation |
|---|---|---|
| **Individual** / small self-serve | Shared tier | Shared OpenProject + shared FalkorDB instance, isolated **logically** by tenant scoping (own FalkorDB graph + tenant-scoped OpenProject projects/groups) |
| **Company** / enterprise | Dedicated tier | **Dedicated OpenProject instance or DB schema + dedicated FalkorDB namespace** for hard isolation and compliance |

- The membership chosen at registration determines tier; the identity plane (§6)
  provisions the right topology.
- **Individuals can be upgraded/merged into a company tenant** (and promoted from shared
  to dedicated tier) if they later join one.
- This gives cheap self-serve onboarding for individuals and small teams, with a hard
  isolation path for enterprises that require it.

## 8. Graph store decision: FalkorDB + Graphiti

Chosen over Memgraph / Neo4j because it directly provides what this product needs:
- **bi-temporal knowledge graph** → maps onto `k360:TemporalEntity/AuditableEntity`;
- **agent memory + incremental real-time updates** → fits webhook-driven projection and
  `k360:AgentMemory`;
- **GraphRAG** (vector + keyword + graph) → powers natural-language insight in the
  dashboard;
- **multi-graph** → per-tenant isolation primitive for the SaaS.

Trade-offs accepted: it's a **property graph, not OWL/SPARQL** (ontology becomes the
schema; equivalence/derived-class logic implemented in Cypher + agent rules, not an OWL
reasoner), and **Graphiti is Python** → the runtime is **polyglot** (TS agents + a Python
Graphiti service exposed over **MCP**).
