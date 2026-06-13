# Remove the orchestrator → event-driven, dynamic, learning agents (and ~93% cheaper)

Scope: Kyndral-365 DOSv2. This answers #10: the orchestrator costs too much and
stops agents from firing dynamically/learning. Good news — **the fix is small and
the event-driven engine is already written, just not wired in.**

## What's actually driving cost (the smoking gun)

There are **two always-on orchestrators**, and one of them is ~95% of the bill:

| Mechanism | File | Cadence | Cost/yr | Keep? |
|---|---|---|---|---|
| **ContinuousOrchestrator** | `server/agents/ContinuousOrchestrator.ts` | **fixed 15s loop**, polls agents whether data changed or not | **$10–15k** | ❌ **remove** |
| BattleRhythm | `server/lib/BattleRhythmOrchestrator.ts` | weekly synthesis (Mon–Fri) | $50–250 | ✅ keep (cheap, strategic) |
| Scheduled deep scans | `server/agents/AgentScheduler.ts` | 20/45/90 min | $100–500 | ⚠️ optional |
| **EventDrivenOrchestrator** | `server/lib/EventDrivenOrchestrator.ts` | on data change | $500–1k | ✅ **activate** |
| A2A bus + Mem0/Letta memory | `server/a2a/*`, `server/lib/Mem0Service.ts` | continuous, ~$0 API | $500–1k | ✅ keep |

The 15-second loop re-analyzes **unchanged** projects all day. That's the waste — and it's also *why* the agents feel un-dynamic: they fire on a clock, not on what actually happened.

## The fix — it's ~2–3 hours, 5 files

`EventDrivenOrchestrator.ts` (467 lines) is **fully implemented** — hash-based change detection, `registerChange()`, `determineAgentsForEvents()` (budget→finops+risk, schedule→tmo/pmo, risk→risk/governance, etc.) — it's just **never started**. Steps:

1. **Disable the polling loop.** `server/agents/DeepAgentBootstrap.ts` (~line 131) — comment out `orchestrator.start(interval)`. *(Immediate ~95% cost drop.)*
2. **Start the event engine.** In `server/index.ts`, after bootstrap: `new EventDrivenOrchestrator(storage)`, register the agents, `startListening(5000)`.
3. **Emit change events from writes.** In the project/work CRUD routes (and the **OpenProject webhook** — see the connector), call `orchestrator.registerChange({type, projectId, prev, next, severity})` when fields actually change.
4. **Feed memory updates in.** In `Mem0Service.storeFact`, call `orchestrator.registerMemoryChange(...)` so fact updates can trigger the right agents.
5. **Cascade via A2A.** Keep the A2A bus for agent→agent ("FinOps budget breach → VRO value reassessment") — but now triggered by events, not a timer.

## Why this also makes them *learn* and *dynamic*

- **Dynamic firing:** an agent runs *because* a budget/schedule/risk changed — milliseconds after the change, only the relevant agents, only on the changed entity. That's the agentic behavior you want.
- **Learning:** memory (Mem0/Letta) stays always-on (≈$0). Pair it with the **outcome-tracking loop** from `GROUNDING_AND_HALLUCINATION.md` §3 (predictions → actuals → accuracy → weighting) and the agents genuinely improve over time instead of re-running the same prompt.
- **Auditable:** every fire has a cause (the event), which is exactly the "not just an LLM" story.

## Cost: before vs after

| | Before (15s polling) | After (event-driven) |
|---|---|---|
| LLM cycles/yr | ~31.5M | ~36k (≈50 changes/day × 2 agents) |
| Annual cost | **$10.6k–15k** | **~$0.5k–1k** |
| Latency to act | up to 15s (loop) | ~ms after change |

**~93% reduction (~$9.9k/yr saved)**, plus lower latency and real dynamism.

## Rules engine — keep it, it's fine

It's a sensible **hybrid** and doesn't need ripping out:
- **Policy-as-code** (`server/services/policyAsCodeExtractor.ts`): LLM extracts rules from documents → **HITL approval** → stored. Good.
- **In-code thresholds** (`rulesEngine.ts`, `UnifiedOrchestrationEngine.ts`): CPI/SPI cutoffs. Fine, but **move the hardcoded thresholds** (CPI 0.75/0.85, SPI 0.75) into config so they're tunable without a deploy.
- **cloud rule services** (the legacy `PalantirRulesService.ts` in DOSv2 source — already deprecated) + **Camunda DMN** for heavier governance. Keep.
- **SmartModelRouter** (heuristic→cheap→premium, caching, free Nemotron tier) — **keep and lean on it harder**; it already makes 60–70% of calls free.

One cleanup: the workflow rules in `UnifiedOrchestrationEngine` are defined but only *partially* firing under the polling model — they become first-class once everything is event-driven (the rule trigger *is* the event).

## Recommended order
1. Flip to event-driven (steps 1–5 above) — biggest cost + dynamism win, lowest risk (the engine exists).
2. Move rule thresholds to config.
3. Add the outcome-tracking loop (turns "memory" into "learning").
4. Retire `ContinuousOrchestrator` entirely once event-driven is validated; keep BattleRhythm as the weekly safety-net scan.
