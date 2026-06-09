# 09 — DOSv2 Reuse Map (LIFT vs REBUILD)

> Scope: scan of `Kyndral-365-Agentic-VRO-Framework-DOSv2` (cloned at `/tmp/dosv2`) to decide,
> per subsystem, how much we can lift into the **Agentic PPM** layer on OpenProject.
> Companion to `07-refactor-from-dosv2.md` (principle) and `05-data-flow-and-knowledge-graph.md`.
> Target Quick slice: **OpenProject webhook → projector → graph → Insights & Risk agent → Insights inbox.**

**Headline:** DOSv2 is *much* further along the OpenProject path than doc 07 assumed. It already has
a working OpenProject APIv3 client, an OpenProject webhook receiver, an OP→graph projector, Mastra
agents with OpenProject-native tools, and an "Agent Alert work package" pattern that is effectively
the Insights inbox. The Quick slice is mostly **LIFT + ADAPT**, not BUILD NEW. The two real
rebuilds are the **graph backend** (Neo4j/"Palantir" → FalkorDB + Graphiti) and the **LLM client**
(OpenRouter → Claude API direct).

---

## 1. Stack reality (what DOSv2 actually is)

| Concern | Reality in DOSv2 | Evidence |
|---|---|---|
| **Agent framework** | **Mastra** (`@mastra/core ^0.24.2`) is the live framework. Agents are `new Agent({id,name,instructions,model,tools})`. There is *also* a parallel, older "Deep Agent" hierarchy (`DeepAgentBase` + `DeepRiskAgent` etc.) with hand-rolled plan/reflect loops that does **not** use Mastra. | `server/mastra/index.ts` (Mastra agents), `server/agents/deep/DeepAgentBase.ts`, `server/agents/deep/DeepRiskAgent.ts` |
| **How agents are defined** | Two ways, redundantly: (a) static Mastra configs in `mastra/index.ts` (pmo/finops/risk/vro/governance/ocm/tmo/planning/integrated/okr/notification), and (b) `DynamicAgentLoader` that builds Mastra agents from storage/config at runtime. Tool sets live in `mastra/tools.ts` (`riskTools`, `pmoTools`, …). | `server/mastra/index.ts:43-220`, `server/mastra/DynamicAgentLoader.ts`, `server/mastra/tools.ts:1528+` |
| **Orchestration / A2A** | Real A2A registry + task executor + agent-card generator. Agents register, get discovered, and route tasks; "facts" are broadcast between agents. Multiple competing orchestrators exist (`AgentOrchestrator`, `UnifiedOrchestrationEngine`, `ContinuousOrchestrator`, `DeepAgentOrchestrator`) — see `ORCHESTRATION_CONSOLIDATION.md`. | `server/a2a/A2ARegistry.ts`, `server/a2a/A2ATaskExecutor.ts`, `server/agents/orchestration/*`, `server/agents/ContinuousOrchestrator.ts` |
| **MCP** | An MCP server layer wraps connectors as MCP services. Notably **`OpenProjectService`** is a full OpenProject APIv3 client (projects, work packages CRUD, statuses, types, priorities, users, testConnection). Other services: Jira, Monday, ServiceNow, a "Palantir" data/AIP provider, policy server. | `server/mcp/OpenProjectService.ts` (real APIv3, basic-auth `apikey:`), `server/mcp/AgentMCPServer.ts`, `server/mcp/MCPServerRegistry.ts`, `server/mcp/PalantirAIPService.ts` |
| **Graph access** | Two distinct things called "graph": (1) **Neo4j** `GraphService` (Cypher: dependency analysis, resource conflicts, impact BFS, root-cause, PageRank) — partly stubbed (`syncProject` is a TODO); (2) a **"Palantir Foundry" ontology** abstraction (`OntologyDataProvider`/`PalantirAIPService`) that the OpenProject sync actually pushes into. Agents read via `OntologyDataProvider`, *not* via Neo4j. | `server/graph/GraphService.ts` (Neo4j), `server/graph/schema.cypher`, `server/services/OntologyDataProvider.ts`, `server/services/sync/OpenProjectToPalantirSync.ts` |
| **Memory** | A 3-layer memory stack: **Mem0** (shared inter-agent facts), **Letta** (per-agent working/archival memory), and a conversation `MemoryManager`. Unified behind `MastraMemoryProvider` (`broadcastFact`, `learn`, `recall`, `archive`, `hasRecentFact`). Deep agents use the same Mem0/Letta libs directly. | `server/mastra/memory.ts`, `server/lib/Mem0Service.ts`, `server/lib/LettaAgentMemory.ts`, `server/lib/MemoryManager.ts` |
| **LLM / Anthropic** | **Not direct Anthropic.** `server/anthropic.ts` is a thin set of task functions that all call `callLLM` → **OpenRouter** (`server/lib/OpenRouterClient.js`) "for cost optimization." Deep agents call through a `SmartModelRouter`. Mastra configs reference `anthropic:claude-sonnet-4-20250514` but fall back to `openai:gpt-4o` if no key. `@anthropic-ai/sdk ^0.37.0` is a dependency but the hot path is OpenRouter. | `server/anthropic.ts:1-2`, `server/lib/SmartModelRouter.ts`, `server/mastra/index.ts:31-38` |
| **Data tier (to be dropped)** | PostgreSQL + Drizzle (`server/db/schema.ts`, `shared/schema.ts`) holds the portfolio data model and the `storage` interface that nearly everything imports. Much of the "real data" today is seed/demo (NextEra / ACME). | `server/storage.ts`, `server/db/schema.ts`, `BRUTAL_HONEST_AUDIT.md` (extensive mock/seed data) |
| **Honesty caveat** | `BRUTAL_HONEST_AUDIT.md` (2026-01-29): "NOT PRODUCTION READY", 300+ issues, lots of hardcoded thresholds, empty endpoints, and integrations "claimed wired but not fully functional." Treat lifted code as a *strong scaffold*, not finished. | `BRUTAL_HONEST_AUDIT.md` |

---

## 2. Keep / Adapt / Drop table

| Subsystem | DOSv2 path | Verdict | Reason |
|---|---|---|---|
| Mastra agent runtime | `server/mastra/index.ts`, `DynamicAgentLoader.ts`, `tools.ts` | **KEEP** | This is the real agent brain. Risk agent config already exists. |
| OpenProject-native agent tools | `server/agents/tools/OpenProjectAgentTools.ts` | **KEEP** | 12 Mastra tools already speak OP APIv3 (health, gantt, create/update WP, budget, risk, relations, **send-notification/Agent Alert**). |
| OpenProject APIv3 client | `server/mcp/OpenProjectService.ts` | **KEEP** | Working client. Add webhook-subscription + comment + custom-field helpers (some already in the agent-tools client). |
| OpenProject webhook receiver | `server/routes/webhooks/openproject.ts` + `server/scripts/bootstrap-openproject.ts` | **ADAPT** | Already receives `work_package:*`/`project:*`/`time_entry:*`, verifies HMAC, dedups agent-origin events, processes async. Re-point its sync target from Palantir to FalkorDB/Graphiti and fan out to the agent. |
| OP→graph projector | `server/services/sync/OpenProjectToPalantirSync.ts` | **ADAPT** | Maps OP WP types → SAFe ontology objects (`syncAll`/`syncIncremental`/`syncSingleWorkPackage`). Keep the mapping logic; swap the sink (`pushToPalantir`) for FalkorDB/Graphiti writes. |
| A2A registry + executor | `server/a2a/*` | **KEEP (trim)** | Solid for multi-agent later. Quick slice (single agent) can ignore it; keep for the roster in doc 04. |
| Memory stack (Mem0/Letta/conv) | `server/mastra/memory.ts`, `server/lib/Mem0Service.ts`, `LettaAgentMemory.ts` | **ADAPT** | Keep the `MastraMemoryProvider` interface; Graphiti is itself a temporal memory graph, so Mem0's fact ledger may be redundant — decide overlap with Graphiti. |
| Risk reasoning (deep) | `server/agents/deep/DeepRiskAgent.ts` | **ADAPT (mine, don't lift wholesale)** | Rich risk heuristics (probability, impact, mitigation coverage, trend forecast, response matrix) but hardwired to the Drizzle `project` shape and the bespoke `DeepAgentBase`/Mem0 loop. Lift the *formulas*, run them via Mastra + OP data. |
| Executive insights generator | `server/executiveInsights.ts` | **ADAPT** | Exactly the Insights output shape we want (headline/health/keyRisks/opportunities/recommendations/KPIs, Zod-validated). Re-point `buildExecutiveContext()` from `storage.get*()` to the graph/OP. |
| Reactive metric watcher | `server/reactiveMetricWatcher.ts` | **ADAPT** | This *is* an inbox-writer: threshold breach → `createIntervention` (= a finding) + activity log + autonomous action. Re-point `createIntervention` to "write to Insights inbox / Agent Alert WP." |
| Impact analysis engine | `server/impactAnalysis.ts`, `server/engines/CrossProjectImpactEngine.ts` | **ADAPT later** | Useful for risk cascades; reads Drizzle today. Not needed for Quick slice; fold in when graph traversal is live. |
| Analytics engines | `server/engines/{Predictive,TrendForecast,PortfolioOptimization,FinancialCalculation}Engine.ts` | **EVALUATE** | Some are thin (audit flags `FinancialCalculationEngine` as near-empty). Lift formulas opportunistically. |
| Neo4j GraphService | `server/graph/GraphService.ts`, `schema.cypher` | **DROP (port concepts)** | Target is FalkorDB (which speaks Cypher/openCypher) + Graphiti. The *queries* (dependency/impact/root-cause/PageRank) are portable; the driver/connection and the half-stubbed `syncProject` are not. |
| "Palantir" ontology layer | `server/mcp/Palantir*.ts`, `server/services/OntologyDataProvider.ts`, `server/ontology/palantir/` | **DROP** | Replaced by FalkorDB+Graphiti as the world model and OpenProject as source of truth. Keep only the SAFe type-mapping tables it encodes. |
| LLM client (OpenRouter) | `server/anthropic.ts`, `server/lib/OpenRouterClient.js`, `SmartModelRouter.ts` | **REPLACE** | Locked decision: Claude API direct (`@anthropic-ai/sdk`, already a dep). Swap `callLLM` impl; keep the per-task prompt functions. |
| PostgreSQL/Drizzle portfolio tables | `server/db/schema.ts`, `shared/schema.ts`, `server/storage.ts` | **DROP** | OpenProject is the source of truth (doc 07 §3). The `storage` dependency is the main thing to sever when lifting. |
| `client/` frontend | `client/` | **DROP** | OpenProject UI + the `modules/agentic_ppm` inbox replace it (doc 07 §3). |
| Jira/Asana/Monday/etc. connectors | `server/jiraClient.ts`, `server/{asana,monday,msProject,planview,rally,serviceNow,smartsheet}Client.ts` | **DROP for Quick slice** | Out of scope; OpenProject is the only source. Keep on the shelf for multi-source later. |
| Langflow | `*LANGFLOW*.md`, related wiring | **DROP** | Audit/`LANGFLOW_REALITY_CHECK.md` indicate it's aspirational; Mastra + Claude suffice. |

---

## 3. Quick-slice build plan (reuse-annotated)

Path: **OpenProject webhook → projector → graph → Insights & Risk agent → Insights inbox.**

### 3a. Webhook receiver — **LIFT + ADAPT**
- **Lift:** `server/routes/webhooks/openproject.ts` (Express route, HMAC verify via `OPENPROJECT_WEBHOOK_SECRET`, async ack-then-process, agent-origin dedup via `sync_source=nextera-agent`) and `server/scripts/bootstrap-openproject.ts` (registers the webhook, creates custom fields / the alerts project).
- **Adapt:** in `processEvent`, replace `getOPToPalantirSync()` with the FalkorDB/Graphiti projector, and add a step that enqueues/triggers the Insights & Risk agent on `work_package:*` / `project:*`.
- *Net: ~80% reuse.* The receiver shell is essentially done.

### 3b. Projector to graph — **ADAPT**
- **Base:** `server/services/sync/OpenProjectToPalantirSync.ts` already does the hard part — fetch OP entities and map WP types → SAFe ontology objects (`syncAll`, `syncIncremental`, `syncSingleWorkPackage`, `syncProject`, `syncWorkPackage`, `syncVersion`).
- **Adapt:** keep the mapping; rewrite the sink `pushToPalantir(...)` to write nodes/edges into **FalkorDB** (episodes/entities into **Graphiti**). Reuse the relationship vocabulary from `server/graph/schema.cypher` and the Cypher query shapes in `GraphService.ts` for FalkorDB (openCypher-compatible).
- *Net: ~50% reuse* (mapping kept, persistence rewritten).

### 3c. Insights & Risk agent — **ADAPT (compose from 3 existing pieces)**
There is no single "Portfolio Insights & Risk" agent, but its parts all exist:
1. **Agent shell:** the `risk` Mastra config in `server/mastra/index.ts:78-94` (instructions cover identification, scoring, prioritization, early-warning) — use as-is; attach OpenProject tools.
2. **Risk math:** lift the heuristics from `server/agents/deep/DeepRiskAgent.ts` — `analyze_risk_probability`, `calculate_risk_impact` (severity multipliers, schedule/cost/quality dimensions), `assess_risk_mitigation` (coverage scoring), `forecast_risk_trends`, `recommend_risk_response` (probability×impact matrix). Re-express as Mastra tools that pull WP fields from the graph/OP instead of the Drizzle `project` object.
3. **Portfolio narrative:** lift `server/executiveInsights.ts` almost verbatim — its `ExecutiveInsightSchema` (headline, portfolioHealth green/amber/red, keyRisks[], opportunities[], recommendations[], kpiHighlights[]) **is the Insights finding format**. Swap `buildExecutiveContext()` from `storage.get*()` to graph/OP reads, and swap `callLLM` for the Claude API.
- *Net: ~60% reuse* (logic exists, plumbing re-pointed).

### 3d. Insights inbox — **ADAPT (pattern exists twice)**
- **Pattern A (write-back to OP):** `opSendNotificationTool` in `OpenProjectAgentTools.ts:512-550` creates an **"Agent Alert" work package** (`[SEVERITY] title`, body, `customField_alert_severity`, `sync_source=nextera-agent`, optional comment on related WP). This is the in-OpenProject inbox surface and is ready to use.
- **Pattern B (finding object):** `reactiveMetricWatcher.ts` builds `Intervention` records (title/severity/description/confidence/suggestedAction/impact/agentSource) + activity logs — the canonical "finding" schema. Use this shape for the inbox row model in `modules/agentic_ppm`.
- **Adapt:** point the agent's findings at the `modules/agentic_ppm` inbox API and/or the Agent Alert WP; drop the Drizzle `createIntervention` persistence.
- *Net: ~70% reuse.*

**Quick-slice reuse summary:** roughly **60–80% liftable per component**, dominated by adaptation (re-point data source + LLM + graph sink), with genuinely new code concentrated in the FalkorDB/Graphiti persistence and the `modules/agentic_ppm` inbox surface.

---

## 4. Gaps — what the Quick slice needs that DOSv2 has nothing for

1. **FalkorDB + Graphiti backend.** DOSv2 has Neo4j (`neo4j-driver`) and a Palantir abstraction — neither is FalkorDB or Graphiti. Need: FalkorDB connection/driver, Graphiti episode/entity ingestion, and temporal/bi-temporal modeling. Cypher queries port over; the persistence layer is new. *(See doc 05 / doc 07 §5 — this supersedes the "keep Neo4j vs triple store" open question with a locked FalkorDB+Graphiti choice.)*
2. **Claude API direct client.** Hot path is OpenRouter (`callLLM`) + `SmartModelRouter`. Need a direct `@anthropic-ai/sdk` client (Messages API, tool-use loop for Mastra) and to drop OpenRouter/SmartRouter. The dependency is already present; the wiring is not.
3. **`modules/agentic_ppm` Insights inbox UI surface.** The Agent Alert WP and `Intervention` record exist as data, but the OpenProject **module/view** where findings surface to users is net-new (Rails module; out of the TS runtime's scope).
4. **Severing the `storage`/Drizzle dependency.** Almost every reusable file imports `./storage` (Postgres). Lifting cleanly requires a thin data-access seam that reads OpenProject/graph instead. This is plumbing, but it touches every file we lift.
5. **OpenProject custom fields / "Agent Alert" type provisioning.** `bootstrap-openproject.ts` references custom fields (`sync_source`, `alert_severity`) and an alerts project; these must actually exist in the target OpenProject instance (the Rails module seeders, per doc 07 §3).
6. **Orchestrator consolidation.** Four overlapping orchestrators exist. Quick slice needs none of them (single agent), but lifting later requires picking one — `ORCHESTRATION_CONSOLIDATION.md` is the guide.
7. **Trustworthy seed data.** Per `BRUTAL_HONEST_AUDIT.md`, much "data" is demo/hardcoded. The Quick slice runs on *our* seeded OpenProject data, so DOSv2's NextEra/ACME seeds are not reusable.

---

## 5. Recommendation

**Lift the Mastra-based agent into a sidecar TS service. Do not rebuild the single agent natively.**

Rationale:
- The Quick slice's expensive parts already exist as DOSv2 code: a working **OpenProject APIv3 client**, an **OpenProject webhook receiver with HMAC + dedup**, an **OP→graph projector with SAFe mapping**, **OpenProject-native Mastra tools including the Agent Alert inbox writer**, and the **exact Insights finding schema** in `executiveInsights.ts` + the risk heuristics in `DeepRiskAgent.ts`. Rebuilding these from scratch would re-derive multiple files of non-trivial mapping/heuristic logic for no benefit.
- The work that remains is **adaptation at three seams**, all well-bounded: (a) graph sink → FalkorDB/Graphiti, (b) LLM client → Claude API direct, (c) data reads → OpenProject/graph instead of Drizzle `storage`. None of these argue for a ground-up rebuild; they argue for a focused fork.
- A **sidecar** keeps the locked topology clean (OpenProject = SoT + UI + Rails module ⟷ TS agent-runtime sidecar ⟷ FalkorDB/Graphiti), lets us keep Mastra/Mem0/A2A on the shelf for the full roster (doc 04) without dragging the Rails app into TS, and isolates the dropped Postgres/`client/` tiers cleanly.
- Caveat from `BRUTAL_HONEST_AUDIT.md`: treat lifted code as a **strong scaffold, not finished** — expect to replace hardcoded thresholds and stubbed branches as you re-point each seam. Strip the `storage` dependency early; it is the single biggest drag on a clean lift.

**Call:** Fork DOSv2's `server/` into an agent-runtime sidecar, delete `client/` + Drizzle portfolio tables + Palantir/Langflow/extra connectors, and adapt the three seams above. Estimated reuse for the Quick slice: ~60–80% of the agent/integration code, with new build concentrated in FalkorDB/Graphiti persistence and the `modules/agentic_ppm` inbox UI.
