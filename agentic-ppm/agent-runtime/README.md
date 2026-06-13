# Agentic PPM — Agent Runtime (sidecar)

TypeScript sidecar that runs the **Portfolio Insights & Risk** agent against an
OpenProject instance. OpenProject stays the source of truth and the UI; this
service only *reasons* over the data and writes findings back.

It implements the **Quick slice** from the reuse map
(`../docs/09-dosv2-reuse-map.md`):

```
OpenProject webhook ─▶ projector ─▶ FalkorDB (+ Graphiti) ─▶ Insights & Risk agent ─▶ Insights inbox
```

## Why a sidecar

Per doc 09 §5, the expensive parts already existed in the Kyndral-365 DOSv2
framework (an OpenProject APIv3 client, a webhook receiver, an OP→graph
projector, the insight finding schema, and the risk math). Rather than rebuild
the agent in Rails, we lift those into this TS service and adapt three seams:

| Seam | DOSv2 | Here |
|---|---|---|
| Graph backend | Neo4j / "FalkorDB ontology" | **FalkorDB** (`src/graph/falkor.ts`) + Graphiti stub (`src/graph/graphiti.ts`) |
| LLM client | OpenRouter (`callLLM`) | **Claude API** (`src/llm/claude.ts`) |
| Data reads | Postgres/Drizzle `storage` | **OpenProject + graph** (`src/openproject/`, projector) |

## Layout

| Path | Role | Provenance |
|---|---|---|
| `src/openproject/client.ts` | OpenProject APIv3 client | **LIFTED** from `OpenProjectService.ts` |
| `src/webhook/server.ts` | Webhook receiver (HMAC, dedup, async) | **ADAPTED** from `routes/webhooks/openproject.ts` |
| `src/projector/projector.ts` | OP entities → graph nodes/edges | **ADAPTED** from `OpenProjectToFalkorDB ontologySync.ts` |
| `src/agents/insightSchema.ts` | Insight finding schema (zod) | **LIFTED** from `executiveInsights.ts` |
| `src/agents/riskHeuristics.ts` | Probability/impact math | **LIFTED** from `DeepRiskAgent.ts` |
| `src/agents/insightsRiskAgent.ts` | The agent (graph + math + Claude) | **COMPOSED** (doc 09 §3c) |
| `src/inbox/inbox.ts` | Agent Alert WP writer | **ADAPTED** from `opSendNotificationTool` |
| `src/graph/falkor.ts` | FalkorDB driver/queries | **NEW** (gap #1) |
| `src/graph/graphiti.ts` | Temporal memory seam | **STUB** (gap #1) |

## Run

```bash
cp .env.example .env   # fill in OPENPROJECT_API_KEY, ANTHROPIC_API_KEY, FalkorDB host
npm install
npm run typecheck      # static check
npm run seed:webhook   # prints the webhook config to add in OpenProject admin
npm run dev            # start the receiver with reload
```

You also need a FalkorDB instance, e.g.:

```bash
docker run -p 6379:6379 falkordb/falkordb:latest
```

To backfill the graph from existing OpenProject data, call the projector's
`syncAll()` (a thin CLI for this is a natural next addition).

## Not yet wired (next lifts)

- **Mastra runtime + A2A** — KEEP per doc 09 §2; lets the single agent grow into
  the full roster (doc 04). The Quick slice calls Claude directly instead.
- **Graphiti service** — currently a logging stub; stand up the real temporal
  graph and replace `recordEpisode`.
- **Inbox UI** — the Rails engine `modules/agentic_ppm` renders these Agent Alert
  work packages (gap #3); this service only writes them.
- **Debounce** — re-runs the agent per work-package event; coalesce bursts per
  project before analysis.
