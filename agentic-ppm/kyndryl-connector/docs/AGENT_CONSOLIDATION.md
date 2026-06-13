# Agent architecture: Mastra agents are the brain; agent-runtime is the grounding layer

> This supersedes the earlier "consolidate onto the agent-runtime" plan. Decision
> made: **keep the Mastra deep agents as the single brain.** The agent-runtime is
> NOT a second agent system — it's the grounded data layer the Mastra agents call.

## The final architecture

```
  Kyndral-365 (Mastra deep agents = THE BRAIN)
    - stateful (Mem0 + Letta), planning/reflection, a2a via AgentSignalBus
    - 13 deep agents: FinOps, VRO, PMO, Governance, Risk, Planning, OCM, TMO,
      OKR, Notification, IntegratedMgmt, …
        │  calls over HTTP for grounded facts; publishes findings
        ▼
  agent-runtime (GROUNDING / DATA layer — NO LLM reasoning)
    - FalkorDB world-model (graph) + computed metrics (deterministic)
    - OpenProject-authored rules engine (GoRules ZEN) — deterministic breaches
    - findings/HITL store + Agent-Alert inbox + OpenProject write-back
    - webhook receiver → projects changes into the graph
        │  reads / writes
        ▼
  OpenProject (datastore + rules authoring UI)
```

## Why this (not the reverse)

The Mastra agents already have the expensive, valuable machinery — stateful
memory (Mem0 + Letta), agent-to-agent collaboration (`AgentSignalBus`),
planning/reflection. Rebuilding that in the runtime was duplicate work (it has
been **removed** — see below). What the Mastra agents lacked is **grounding**:
a graph world-model, computed-not-generated metrics, and a deterministic rules
engine. That's exactly what the agent-runtime provides. So: brain stays in
Kyndral; grounding lives in the runtime; they talk over HTTP.

## What was removed from the agent-runtime (the duplicate brain)

Deleted — these duplicated the Mastra agents and are gone:
`reasoningAgents`, `insightsRiskAgent`, `insightSchema`, `narrativeGenerator`,
`projectAssessor`, `riskHeuristics`, `agents/domains/*`, `agents/events/*`,
`agents/autonomy/*`, `llm/*`, `letta/*`. The runtime no longer calls an LLM.

## What the agent-runtime keeps (the grounding the Mastra agents call)

| Endpoint | What the Mastra agents get |
|---|---|
| `GET /api/metrics` | computed portfolio metrics (deterministic Cypher + formulas) |
| `GET /api/project-status` | per-project computed status |
| `GET /api/rules` | the OpenProject-authored rules |
| `GET /api/findings` | deterministic rule/detector breaches |
| `POST /api/findings/:id/approve|reject` | HITL decisions |
| `POST /api/sweep` | run the deterministic detector + rules sweep |
| `POST /webhooks/openproject` | change feed (the runtime projects it into the graph) |
| (graph) | FalkorDB world-model the agents reason over |

The runtime's `roster` now exists only to **attribute** deterministic
findings (detector/rule breaches) — it is not a set of reasoning agents.

## How the Mastra agents use it (integration sketch)

In `DeepAgentBase` (Kyndral), add a thin client to the agent-runtime
(`AGENT_RUNTIME_URL` + bearer `AGENT_RUNTIME_TOKEN`):
- Before reasoning, pull grounded facts: `GET /api/metrics`, the relevant graph
  slice, and current rule results — so numbers come from the graph, not the LLM.
- When the agent concludes something actionable, `POST` it as a finding so it
  surfaces in the HITL surfaces and (optionally) OpenProject.
- The runtime's webhook change-feed can be the stimulus that wakes the right
  Mastra agent (event-driven), instead of any cron.

That keeps the Mastra brain intact AND makes its numbers grounded — the
"computed, not generated" guarantee — without a second agent system.
