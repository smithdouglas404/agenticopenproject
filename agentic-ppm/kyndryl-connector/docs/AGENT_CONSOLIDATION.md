# One agent system: consolidate Kyndral's deep agents into the agent-runtime

## The problem

There are currently **two agent systems** with overlapping domains:
- **Kyndral-365** — 13 "deep agents" (`server/agents/deep/*`) on Mastra +
  `DeepAgentBase` + `ContinuousOrchestrator` + a2a + SmartModelRouter.
- **agent-runtime** — a 9-agent roster + rules agent over the FalkorDB graph,
  with grounding (evidence/citations), the learning loop, the rules engine,
  and the HITL findings lifecycle.

Running both = double LLM cost, contradictory findings on the same entity, two
memory stores, two orchestrators. Your own commit #14 ("Make agent-runtime the
sole agent system") already chose the fix; this finishes it.

## The decision

**One brain: the agent-runtime.** Kyndral *displays* agent output and routes
human decisions — it does **not** run agents. The deep agents' domain expertise
moves into the agent-runtime roster.

## They map almost 1:1

| Kyndral deep agent | → agent-runtime roster id |
|---|---|
| DeepPMOAgent | `strategic-pmo` |
| DeepGovernanceAgent | `governance` |
| DeepFinOpsAgent | `finops` |
| DeepVROAgent | `vro` |
| DeepOKRInferenceAgent | `okr` |
| DeepPlanningAgent | `planning` |
| DeepOCMAgent | `ocm` |
| DeepTMOAgent | `tmo` |
| DeepRiskAgent | `strategic-pmo` (risk detectors) / new `risk` roster entry |
| DeepNotificationAgent | `notification` |
| DeepIntegratedMgmtAgent | cross-cutting — fold into the reconciliation pass |
| GenericDeepAgent / DeepAgentWithRAG | the base reasoning path (already in `reasoningAgents.ts`) |

## Migration plan

1. **Port the domain expertise.** For each deep agent, copy its system
   prompt + its `server/agents/attributes/*AgentAttributes.ts` (the SAFe/PMBOK
   attribute definitions — the genuinely valuable part) into the matching
   `agent-runtime/src/agents/roster.ts` entry's `purpose`/prompt, and any
   domain-specific checks into `detectors.ts`. The runtime's agents are
   currently generic; this makes them as smart as the Kyndral ones, but
   grounded + learning.
2. **Add a `risk` roster agent** if DeepRiskAgent carries logic not covered by
   the existing detectors.
3. **Stop running agents in Kyndral.** Disable `DeepAgentBootstrap` /
   `ContinuousOrchestrator` (also the ~$10–15k/yr cost). Keep the deep-agent
   files as reference until the port is verified, then retire them.
4. **Kyndral reads, doesn't run.** Agent pages render from `/api/agent/*`
   (findings, metrics, learning) and route approve/reject back to the runtime —
   already wired (`ApprovalQueue.tsx`, `agentFindings.routes.ts`, `ai-sdk/`).
5. **Keep the good Mastra bits as runtime features, not a parallel system.** If
   specific Mastra tools/workflows are valuable (e.g. scenario analysis),
   re-implement them as agent-runtime capabilities — one system, not two.

## End state

One roster, one FalkorDB graph, one HITL surface, one learning loop, one cost
center, event-driven (not the 15s loop). Kyndral is the UI; the agent-runtime
is the brain; OpenProject is the datastore. No contradictory findings, no double
spend.

## Why not the reverse (agents stay in Kyndral, runtime is just a graph)?

That couples reasoning to the UI deploy, re-creates the two-orchestrator cost
problem, and splits memory/learning across two services. The grounding +
learning + rules engine already live in the agent-runtime; bring the agents to
the data, not the data to the UI.
