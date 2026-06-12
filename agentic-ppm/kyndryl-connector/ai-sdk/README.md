# Agentic UI — Vercel AI SDK (v5) integration for Kyndral-365 DOSv2

This pack is the **agentic UI**: your UI, your design, with the agent runtime's
intelligence streamed into it as **typed widgets**. The model streams text and
tool calls over one HTTP route; the client renders each tool result as a real
React component (metric cards, finding cards, track records) — not as prose.

The grounding story carries all the way through:

- **Tools return computed data.** Every tool calls the agent-runtime sidecar's
  deterministic endpoints (`/api/metrics`, `/api/findings`, `/api/learning`, …).
  Nothing the tools return passed through an LLM.
- **The model is instructed to cite, not invent.** `AGENTIC_SYSTEM_PROMPT`
  encodes the trust rules from `docs/GROUNDING_AND_HALLUCINATION.md`: reference
  metric ids, cite evidence, abstain on thin data, never invent numbers.
- **Widgets render the structured outputs directly.** The numbers on screen
  come from the graph, NOT from the LLM's text — the model literally cannot
  alter what the `<MetricsGrid/>` shows. Its text only explains and prioritizes.

```
Browser ──useChat──▶ POST /api/agent-chat (Express)
                        │ streamText(anthropic, tools, stepCountIs(8))
                        ▼
                  agenticTools ──fetch──▶ agent-runtime sidecar (:8745)
                                            /api/metrics    (computed, no LLM)
                                            /api/findings   (evidence + confidence)
                                            /api/learning   (provable track record)
                                            /api/findings/:id/approve|reject (HITL)
```

## Files

| File | What it is |
|---|---|
| `server/agentRuntimeClient.ts` | Typed fetch client for the sidecar (bearer `CONSOLE_TOKEN` optional). Exports `Finding`, `Metric`, `AgentAccuracy`, … mirrors of the runtime shapes. |
| `server/tools.ts` | The Vercel AI SDK tool set (`agenticTools`) + `AGENTIC_SYSTEM_PROMPT`. Every tool returns structured data, never prose. |
| `server/routes/agentChat.route.ts` | Express route factory: `POST /api/agent-chat` streaming UI messages. |
| `client/AgenticChat.tsx` | `useChat` surface — renders text parts + maps tool parts to widgets. |
| `client/widgets.tsx` | Pure presentational React+Tailwind widgets typed to the tool outputs. |

## Install

```sh
npm i ai @ai-sdk/react @ai-sdk/anthropic zod
```

(`ai` + `zod` are used server-side; `ai` + `@ai-sdk/react` client-side.)

## Mount

**Server** (wherever Kyndral registers routes — make sure `express.json()` runs first):

```ts
import express from "express";
import { initAgentChatRoute } from "./ai-sdk/server/routes/agentChat.route";

app.use(initAgentChatRoute(express.Router()));
```

**Client** — drop into the ClarityChat page as a tab/panel, or standalone:

```tsx
import AgenticChat from "./ai-sdk/client/AgenticChat";

<Route path="/agent-chat" component={AgenticChat} />
```

**Env:**

| Var | Required | Meaning |
|---|---|---|
| `ANTHROPIC_API_KEY` | yes | read by `@ai-sdk/anthropic` |
| `ANTHROPIC_MODEL` | no | model id override (default `claude-sonnet-4-5`) |
| `AGENT_RUNTIME_URL` | no | sidecar base URL (default `http://localhost:8745`) |
| `CONSOLE_TOKEN` | no | bearer token, if the sidecar has one configured |

## The tools (and the widget each one feeds)

| Tool | Calls | Returns | Widget |
|---|---|---|---|
| `getPortfolioMetrics` | `GET /api/metrics` | computed metrics with `id` + `formula` | `<MetricsGrid/>` — value cards, "computed" tag, formula on hover |
| `getFindings` | `GET /api/findings` | findings incl. parsed evidence + confidence | `<FindingCard/>` list — severity color, `entityId · metric = value` citations, confidence bar, "AI narrative" tag |
| `getAgentRoster` | `GET /api/roster` | agents + open/total counts | `<RosterList/>` |
| `getAgentTrackRecord` | `GET /api/learning` + roster | per-agent accuracy ("84% over 12 resolved", honest `null` under 3) | `<TrackRecordList/>` |
| `getProjectStatus` | `GET /api/project-status` | per-project banner status + metric snapshot | `<ProjectStatusList/>` |
| `approveFinding` / `rejectFinding` | `POST /api/findings/:id/approve\|reject` | decision result (HITL — model only calls on explicit user request) | inline confirmation chip |
| `triggerSweep` | `POST /api/sweep` | `{detected, newFindings, published}` | `<SweepResult/>` |

## Add a tool in 10 lines

Add to `agenticTools` in `server/tools.ts`; the model can use it immediately.
Render `part.output` in `AgenticChat.tsx` (a `tool-getCapacityForecast` case) to
give it a widget — until then it still works, the model just narrates the data.

```ts
const getCapacityForecast = tool({
  description: "Computed capacity forecast per assignee. Cite values verbatim.",
  inputSchema: z.object({ weeks: z.number().default(4) }),
  execute: async ({ weeks }) => {
    const res = await fetch(`${process.env.AGENT_RUNTIME_URL}/api/capacity?weeks=${weeks}`);
    return (await res.json()) as { assignee: string; load: number }[]; // structured, never prose
  },
});
// …and add `getCapacityForecast` to the agenticTools export.
```

## SmartModelRouter note

This fits the SmartModelRouter philosophy: **the chat model can be cheap,
because the data is precomputed.** The expensive thinking (detectors, metrics,
outcome resolution) already happened deterministically in the runtime; the chat
model only routes tool calls and explains structured results. Swap
`ANTHROPIC_MODEL` per request/tier if you wire it through the router — the
grounding guarantees don't change, because they never depended on the model.
