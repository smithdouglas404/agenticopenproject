# INSTALL THIS FILE AS `CLAUDE.md` AT THE ROOT OF THE KYNDRAL REPO

> Copy everything below the line into `CLAUDE.md` at the root of
> `Kyndral-365-Agentic-VRO-Framework-DOSv2`. Claude Code reads `CLAUDE.md`
> automatically at the start of EVERY session in that repo — after this is
> installed, you can vibe-code ("integrate this OpenProject work item",
> "show agent findings on this page") and any session will already know how.

---

# Kyndral-365 — project context for Claude

## Architecture (three deployables, one product)

- **This repo (Kyndral-365)** — THE application: React/Vite client (Tailwind,
  shadcn/ui, Vercel AI SDK) + Express/Drizzle/Postgres server, Mastra agents,
  a2a bus. This is the only UI users see.
- **OpenProject** — the datastore / system of work. Projects and work packages
  physically live there. Users never see its UI; we read/write via APIv3.
- **agent-runtime** (sidecar service, lives in the `agenticopenproject` repo
  under `agentic-ppm/agent-runtime/`, deployed separately) — syncs OpenProject
  into a **FalkorDB** graph, runs 9 reasoning agents + deterministic detectors
  over it, owns the findings/HITL lifecycle and the learning loop.
  HTTP API: `GET /api/findings|metrics|learning|roster|project-status`,
  `POST /api/findings/:id/approve|reject`, `POST /api/sweep`.
  Env to reach it: `AGENT_RUNTIME_URL` (+ `AGENT_RUNTIME_TOKEN` bearer if set).

The ontology layer: the UI reads ontology objects (Project/Feature/Story/Task/
Risk) via `/api/palantir/ontology/*` routes backed by
`server/FalkorOntologyDataProvider.ts` (FalkorDB; Palantir has been replaced —
keep the route URLs, never reintroduce Foundry).

## OpenProject integration — how to do common things

All building blocks are already in this repo (originally authored in
`agenticopenproject:agentic-ppm/kyndryl-connector/`, kept in sync from there):

| Task | Use |
|---|---|
| Pull projects/work packages IN | `server/openProjectClient.ts` → `syncProject()`; registered as `'openproject'` in `IntegrationSyncService` (both switches) and the sync scheduler |
| Real-time inbound | `server/routes/webhooks/openproject.ts` (`POST /webhooks/openproject`, HMAC `X-OP-Signature`, echo-guarded) |
| Push a UI edit OUT to OpenProject | `server/openProjectWriteback.ts` → `pushEntityUpdate()` / `pushProjectUpdate()` (handles lockVersion + 409 retry); REST: `PATCH /api/openproject/entities/:entityType/:externalId` |
| Create a work package from the UI | `POST /api/openproject/projects/:externalProjectId/work-packages` or `writeback.createLinkedWorkPackage()` — store the returned `id` as the entity's `externalId` |
| Deep link to OpenProject | `GET /api/openproject/link/:entityType/:externalId` or `writeback.deepLink()` |
| Mark a UI element as OpenProject-backed | `client/src/openproject/SourceBadge.tsx`; detect with `isOpenProjectEntity(entity)` (`sourceSystem === 'openproject'` + `externalId`) |
| Make any save bidirectional | wrap the save handler with `useBidirectionalSave` from `client/src/openproject/OpenProjectEditGuard.tsx` |
| Agent insights + HITL approve/reject in the UI | `client/src/openproject/ApprovalQueue.tsx` + server proxy `server/routes/agentFindings.routes.ts` (`/api/agent/*`) |
| Set a threshold rule | OpenProject → agentic_ppm module → Rules; runtime evaluates; breaches appear in both UIs (read-only view: `client/src/openproject/RulesPanel.tsx`, proxy `/api/agent/rules`; design: `docs/RULES_ENGINE.md`) |
| Author a decision-table rule | GoRules JDM on AgentRule (kind='decision'); visual editor `DecisionEditor.tsx` (`@gorules/jdm-editor`); runtime evaluates via ZEN (design: `docs/DECISION_ENGINE_GORULES.md`) |
| Agent chat with grounded widgets (Vercel AI SDK) | `ai-sdk/` — tools in `ai-sdk/server/tools.ts`, route `POST /api/agent-chat`, widgets + `AgenticChat` in `ai-sdk/client/` |
| OKR progress from real delivery | `server/okrRollupService.ts` (KR progress = Σ entity progress × contribution%); routes in `server/routes/okrRollup.routes.ts` |

Per-page integration recipes: `docs/UI_BIDIRECTIONAL_WIRING_MAP.md`.

## Rules that keep this system trustworthy (do not regress these)

1. **Numbers are computed, never generated.** Metrics come from
   `/api/agent/metrics` (deterministic Cypher with audit formulas) or Drizzle
   aggregates. The LLM explains and prioritizes; it must never invent a number.
   Keep the computed-vs-"AI narrative" labeling in the UI.
2. **Findings carry evidence.** Agent findings cite `evidence[]`
   (entityId · metric = value) and `confidence`. Render them; never strip them.
3. **HITL gates actions.** Agent actions execute only on human approval
   (ApprovalQueue / HITLApprovalCenter). Decisions are training labels —
   they feed per-agent accuracy and severity auto-tuning. Don't bypass.
4. **Event-driven, not polling.** `EventDrivenOrchestrator` fires agents on
   real changes (CRUD diffs, OpenProject webhooks, memory updates). Never
   re-enable the `ContinuousOrchestrator` 15-second loop (it cost ~$10–15k/yr).
5. **Echo prevention.** Outbound writes to OpenProject are marked
   (`wasRecentlyPushed`, `[sync:kyndral-365]`); the webhook skips our own
   echoes. Preserve this when touching either path.
6. **OpenProject field mapping** lives in `openProjectClient.ts`
   (`TYPE_BUCKET`, status/priority maps) and its reverse in
   `openProjectWriteback.ts`. Change them together or sync drifts.
7. **No mock data.** Every UI number must trace to: OpenProject sync, a user
   setup screen, or a computed formula (see `docs/MOCK_DATA_TO_REAL.md`).
8. **Rules are authored in OpenProject** (the agentic_ppm module is the system
   of record for rules). The runtime evaluates them **event-driven** (on the
   OpenProject webhook change, on the changed entity) **+ a periodic safety
   sweep** — never a tight scan loop. On a breach, the fan-out must reach
   **both UIs** (OpenProject native Agent Alert WP + comment + banner + the
   alerts.json inbox, AND the Kyndral ApprovalQueue / RulesPanel). Kyndral's
   rules view is read-only; don't move authoring out of OpenProject.

## Rules engine

Threshold/rules live in the forked OpenProject (`modules/agentic_ppm`, stored as
`AgentRule` rows) — OpenProject is the **system of record for rules**. The
agent-runtime (`agentic-ppm/agent-runtime/src/rules/`) pulls `rules.json`,
evaluates each rule against the FalkorDB graph **event-driven on OpenProject
webhook changes + a periodic safety sweep** (remembering previous values for
`delta_*`/`changed`/`crossed_*`, respecting `cooldown_minutes`), and on a breach
records a finding (→ Kyndral ApprovalQueue/RulesPanel + AI-SDK) AND notifies
OpenProject (Agent Alert WP + comment + banner + `POST /agentic_ppm/api/alerts.json`)
— so the same breach reaches both UIs. The Kyndral side is read-only
(`client/src/openproject/RulesPanel.tsx`, via the `/api/agent/rules` proxy and
`/api/agent/findings?type=RuleBreach`); the full contract is in
`docs/RULES_ENGINE.md`.

A rule has a `kind`: `'threshold'` (the single-metric `metric operator threshold`
rule above) or `'decision'` (a GoRules **JDM** — a decision table / decision graph
— carried in a `jdm` field on the AgentRule and evaluated in-process by the
GoRules **ZEN** engine against the entity context, returning
`{breach, severity?, message?, action_kind?, metric?, value?}`). Only the *decide*
step differs; the event+sweep trigger, previous-value memory, cooldown/dedup, and
dual-UI fan-out are reused unchanged. Decision rules are authored by pasting JDM
JSON in OpenProject (Phase 1) or visually via `client/src/openproject/DecisionEditor.tsx`
(the `@gorules/jdm-editor` wrapper, Phase 2). See `docs/DECISION_ENGINE_GORULES.md`.

## Env vars (integration)

```
OPENPROJECT_BASE_URL=…        # the OpenProject instance
OPENPROJECT_API_KEY=…         # basic auth: apikey:<key>
OPENPROJECT_WEBHOOK_SECRET=…  # X-OP-Signature HMAC
AGENT_RUNTIME_URL=…           # the sidecar
AGENT_RUNTIME_TOKEN=…         # sidecar CONSOLE_TOKEN, if set
FALKORDB_HOST/PORT/GRAPH/PASSWORD  # ontology graph
ANTHROPIC_API_KEY / ANTHROPIC_MODEL # AI SDK chat route
```

## Cross-repo note

The reference implementations and docs originate in the public repo
`smithdouglas404/agenticopenproject` under `agentic-ppm/kyndryl-connector/`
(strategy docs: `GROUNDING_AND_HALLUCINATION.md`, `ORCHESTRATION_AND_RULES.md`,
`UI_STRATEGY.md`, `SCHEMA_AND_OPENPROJECT_MAPPING.md`, `PALANTIR_TO_FALKORDB.md`).
If something here seems missing or stale, read that folder's latest `main`.
