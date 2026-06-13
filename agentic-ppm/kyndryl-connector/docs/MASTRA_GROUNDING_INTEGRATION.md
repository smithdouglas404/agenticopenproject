# Wiring Mastra agents to the runtime for grounding

The decision (see `docs/AGENT_CONSOLIDATION.md`): the **Mastra deep agents are
the brain** (Mem0 + Letta memory, planning/reflection, a2a via `AgentSignalBus`);
the **agent-runtime is the grounding / data layer** (FalkorDB world-model +
computed-not-generated metrics + the OpenProject-authored rules engine). The
runtime does no LLM reasoning. This doc is exactly how the brain calls the
grounding layer so it stops inventing numbers.

The client is `client/src/openproject/agentRuntimeClient.ts`
(`AgentRuntimeClient`). Construct one in `DeepAgentBase`.

## 1. Where to call it in DeepAgentBase

Two hook points around the reasoning step:

```ts
import { AgentRuntimeClient } from "@/openproject/agentRuntimeClient";

class DeepAgentBase {
  // Server-side agent → talk to the runtime directly with a bearer token.
  // (In the browser, omit baseUrl/token and it uses the /api/agent proxy.)
  private runtime = new AgentRuntimeClient({
    baseUrl: process.env.AGENT_RUNTIME_URL,     // e.g. https://agent-runtime.up.railway.app
    token: process.env.AGENT_RUNTIME_TOKEN,     // the runtime CONSOLE_TOKEN
  });

  async run(task: Task) {
    // (A) BEFORE reasoning — pull grounded facts.
    const [metrics, rules, status] = await Promise.all([
      this.runtime.getMetrics(),
      this.runtime.getRules(),
      this.runtime.getProjectStatus(),
    ]);
    const graph = task.nodeId ? await this.runtime.getGraphSlice(task.nodeId) : null;

    const grounding = this.formatGrounding(metrics, rules, status, graph);
    const result = await this.reason({ ...task, grounding });   // LLM sees the facts

    // (B) AFTER reasoning — publish an actionable conclusion as a finding.
    if (result.actionable) {
      await this.runtime.publishFinding({
        type: result.kind,
        agentId: this.id,
        severity: result.severity,
        title: result.title,
        body: result.body,
        narrative: result.narrative,
        nodeId: task.nodeId,
        projectId: task.projectId,
        // Cite the metric ids / entities the conclusion rests on:
        evidence: JSON.stringify(result.evidence),  // [{entityId, metric, value}]
        confidence: result.confidence,
      });
    }
    return result;
  }
}
```

- **(A)** runs before any LLM call. The returned metrics/rules/status/graph are
  the authoritative facts.
- **(B)** runs after the LLM concludes; `publishFinding` surfaces it in the HITL
  surfaces (`AgentConsole`, `ApprovalQueue`) and, on human approval, mirrors back
  to OpenProject.

The runtime's webhook change-feed can also be the **stimulus** that wakes the
right agent (event-driven), instead of a cron — do not re-add polling.

## 2. Feeding grounded facts into the prompt (cite ids, never invent numbers)

Format the grounding as an explicit, cited block and instruct the model to use
only those numbers:

```ts
formatGrounding(metrics, rules, status, graph) {
  const lines = [
    "## GROUNDED FACTS (authoritative — do not recompute or invent numbers)",
    "Every figure you state MUST cite one of these metric ids in [brackets].",
    "",
    "### Metrics (computed by the runtime)",
    ...metrics.metrics.map((m) => `- [${m.id}] ${m.label} = ${m.value}` +
      (m.formula ? `  (formula: ${m.formula})` : "")),
    "",
    "### Active rules (authored in OpenProject)",
    ...rules.map((r) => `- ${r.name}: ${r.metric} ${r.operator} ${r.threshold} → ${r.severity}`),
    "",
    "### Project status (computed)",
    ...status.map((s) => `- ${s.projectName ?? s.id}: ${s.severity}`),
  ];
  if (graph) lines.push("", "### Local graph slice", JSON.stringify(graph));
  return lines.join("\n");
}
```

Prompt rule to enforce in the system message:

> Use only the numbers in GROUNDED FACTS. When you state a metric, cite its id in
> brackets, e.g. "schedule variance is 14% [pm:scheduleVariance]". If a number you
> need is not in GROUNDED FACTS, say so and request it — do not estimate.

This is the "computed, not generated" guarantee at the prompt boundary: the LLM
narrates and decides; the runtime owns every number.

## 3. Publishing findings back so they show in the HITL surfaces

`publishFinding(input)` POSTs to the runtime's findings store. The same record
then appears in:

- `ApprovalQueue.tsx` — `GET /api/agent/findings?status=published`, where a human
  Approves (executes the gated action + trains the agent) or Rejects.
- `AgentConsole.tsx` — the same queue embedded under "Findings & recommendations".

Carry **evidence** (the `[{entityId, metric, value}]` JSON) and a **confidence**
so the queue can render the evidence trail and confidence chip. The evidence is
how a reviewer audits that the conclusion traces back to grounded metrics.

## 4. Memory stays with the agents; the runtime is only the data source

Do **not** move agent memory into the runtime. Mem0 + Letta remain the agents'
state (history, reflections, learned preferences). The runtime is stateless from
the brain's perspective — it answers "what are the facts right now?" and stores
findings/HITL decisions. Keep the split:

| Concern | Owner |
|---|---|
| Planning, reflection, a2a, conversation | Mastra agents (Kyndral) |
| Long-term memory | Mem0 + Letta (Kyndral) |
| Numbers, graph world-model, rules, findings/HITL | agent-runtime |

That keeps the brain intact and its numbers grounded — without a second agent
system.
