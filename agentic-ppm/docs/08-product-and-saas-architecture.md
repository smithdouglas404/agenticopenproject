# 08 — Product Shape, SaaS & Experience (v2 — supersedes earlier open questions)

This document records the decisions made after the Phase-0 blueprint, based on direct
direction. Where it conflicts with docs 00–07, **this document wins** and those docs are
amended to point here.

## 1. It is ONE product, built on top of OpenProject

The polished, agent-driven **living dashboard and OpenProject are one thing** — not a
separate app competing with OpenProject. We put a **polished interface on top of
OpenProject** so that:

- people who don't already have a project tool can use *our* interface as their PPM tool;
- OpenProject is the embedded **PPM engine + system of record/storage** underneath;
- the agentic insight layer is part of the same product, not a bolt-on.

> Mental model: **OpenProject is the engine and the system of record. Our interface is the
> face. The knowledge graph is the brain.** All one product.

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

## 6. SaaS model & authentication

- The SaaS front door **reuses the existing DOSv2 login/registration approach** (the
  TypeScript app in the
  [DOSv2 repo](https://github.com/smithdouglas404/Kyndral-365-Agentic-VRO-Framework-DOSv2)).
  Its auth flow will be read in detail and reused rather than reinvented.
- OpenProject sits behind it as a service; the DOSv2-derived login governs access and
  provisions the tenant.

## 7. Tenancy — membership-driven

A tenant is created based on **how the member joins**:

- **Company tenant** — an organization; all its members share one tenant boundary.
- **Individual tenant** — a single person who joined on their own.

The membership chosen at registration determines the boundary. Isolation:

- **One FalkorDB graph per tenant** (FalkorDB multi-graph = clean, cheap isolation), for
  both company and individual tenants.
- **OpenProject data tenant-scoped** (per-tenant projects/groups; instance-per-tenant
  only if a company requires hard isolation).
- Individuals can later be **upgraded/merged into a company tenant** if they join one.

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
