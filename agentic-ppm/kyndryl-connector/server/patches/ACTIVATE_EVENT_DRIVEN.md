# Activate event-driven orchestration (kill the 15s polling loop)

Companion to `eventDrivenBootstrap.ts` in this folder. Background + cost
analysis: `docs/ORCHESTRATION_AND_RULES.md`. The engine
(`server/lib/EventDrivenOrchestrator.ts`, 467 lines) is **fully implemented and
never instantiated** — these are the exact wiring steps. ~2–3 hours, 5 files.

## Step 1 — Disable the polling ContinuousOrchestrator

`server/agents/DeepAgentBootstrap.ts`, **~line 131**, comment out the start call:

```ts
// DISABLED: 15s polling loop re-analyzed unchanged projects all day (~$10-15k/yr).
// Replaced by EventDrivenOrchestrator — see server/patches/eventDrivenBootstrap.ts.
// orchestrator.start(interval);
```

This alone is the ~95% cost drop. Everything after this restores the *useful*
agent activity, now triggered by actual changes.

## Step 2 — Copy + call the bootstrap

Copy `eventDrivenBootstrap.ts` → Kyndral `server/patches/eventDrivenBootstrap.ts`
(its imports are relative to `server/`). Then in `server/index.ts`, after the
agents are bootstrapped:

```ts
import { activateEventDrivenOrchestration, registerCrudChangeHooks } from "./patches/eventDrivenBootstrap";

const orchestrator = activateEventDrivenOrchestration(storage, agents);
// `agents` = the same name→instance map DeepAgentBootstrap built for
// ContinuousOrchestrator (finops, risk, tmo, pmo, governance, vro, …).
export const crudHooks = registerCrudChangeHooks(orchestrator);
```

`startListening(5000)` is called inside — a 5s drain tick that is idle (≈$0)
when nothing changed.

## Step 3 — Emit change events from CRUD routes

In the project/feature/story/task/risk update routes, diff prev vs next and
emit only on **material** fields (status, budget/EVM fields, dates, riskScore) —
`eventDrivenBootstrap.ts` ships the diff logic:

```ts
const prev = await storage.getProject(id);
const next = await storage.updateProject(id, req.body);
crudHooks.onEntityUpdated("project", id, prev, next, id);   // emits 0..n registerChange
```

and on creates: `crudHooks.onEntityCreated("task", task.id, projectId)`.

## Step 4 — Wire the OpenProject webhook

Copy `server/routes/webhooks/openproject.ts` (from this connector) and mount it
with the orchestrator so external changes also fire agents in real time:

```ts
import { initOpenProjectWebhook } from "./routes/webhooks/openproject";
app.use(initOpenProjectWebhook(express.Router(), {
  client: openProjectClient,
  orchestrator,
  sourceSystemId: "openproject",
}));
```

Set `OPENPROJECT_WEBHOOK_SECRET` and configure the URL in OpenProject
(Administration → Webhooks). Mapping: `work_package:created` → `scope`,
`work_package:updated` → `schedule`, `project:*` → `status` — which
`determineAgentsForEvents()` routes to the right agents (budget→finops+risk,
schedule→tmo/pmo, risk→risk/governance).

## Step 5 — Feed memory updates in

In `server/lib/Mem0Service.ts`, at the end of `storeFact(...)`:

```ts
orchestrator.registerMemoryChange({ kind: "fact", projectId, fact });
```

(Inject the orchestrator into Mem0Service at construction, or import the
singleton from index.ts.) Fact updates can now trigger the right agents, which
is what makes the memory layer *learning* rather than passive.

## Step 6 — Verify, then retire

1. Boot the server; confirm the log line `[event-driven] orchestrator listening`.
2. Edit a project budget in the UI → FinOps + Risk agents fire within ~5s; edit
   a description → **nothing** fires.
3. Push an OpenProject work-package update → webhook 200, sync runs, tmo/pmo fire.
4. After a week of clean operation, delete `ContinuousOrchestrator` usage
   entirely; keep BattleRhythm as the weekly safety-net scan.

## Expected cost impact (~93% reduction)

From `docs/ORCHESTRATION_AND_RULES.md`:

| | Before (15s polling) | After (event-driven) |
|---|---|---|
| LLM cycles/yr | ~31.5M | ~36k (≈50 changes/day × 2 agents) |
| Annual cost | **$10.6k–15k** | **~$0.5k–1k** |
| Latency to act | up to 15s (loop) | ~ms after change |

**≈ $9.9k/yr saved**, plus lower latency, per-event auditability ("every fire
has a cause"), and genuinely dynamic agents.

## Rollback

Re-enable `orchestrator.start(interval)` in DeepAgentBootstrap.ts and remove
the `activateEventDrivenOrchestration` call. The two systems can also coexist
briefly during validation (events fire faster; the poller is just redundant).
