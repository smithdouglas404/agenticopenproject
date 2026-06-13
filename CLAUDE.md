# agenticopenproject — architecture & guardrails for Claude

This repo is the **forked OpenProject** (full Rails monorepo at root) **plus**
the agentic layer under `agentic-ppm/`. It is one of **three separate
deployables** that make up the product. Read this before changing anything.

## THE THREE DEPLOYABLES (never merge them into one codebase)

1. **OpenProject fork** — this repo's root (Rails). The datastore / system of
   work. Embeds the `modules/agentic_ppm` plugin (rules authoring, insights).
   Deploys on its own (Railway: `railway.json` → `docker/prod/Dockerfile`,
   `env MIGRATE=true ./docker/prod/web`).
2. **agent-runtime** — `agentic-ppm/agent-runtime/` (Node/TS sidecar). The
   GROUNDING/DATA layer: syncs OpenProject → FalkorDB graph, computes metrics,
   evaluates the OpenProject-authored rules engine, owns findings/HITL +
   OpenProject write-back. It does NOT do LLM reasoning — the Mastra agents in
   Kyndral-365 are the brain and call this for grounded facts. Deploys on its own.
3. **Kyndral-365** — a SEPARATE repo (`Kyndral-365-Agentic-VRO-Framework-DOSv2`).
   The UI/server. Talks to OpenProject and the agent-runtime **over HTTP**.

They integrate **via APIs**, not by vendoring code.

## 🚫 HARD RULE — DO NOT VENDOR

**Never copy the OpenProject monorepo (this repo's root, 16k+ files) into
Kyndral-365 or any app repo.** It was done once and it broke the Kyndral build
for days. If you think you need code from another repo, integrate over the API
or copy the specific small module — never the whole tree. A CI guard enforces
this; do not work around it.

## Other load-bearing rules

- **FalkorDB is the only ontology backend.** No Palantir/Foundry. (`agentic-ppm/agent-runtime/src/graph/falkor.ts`, `src/ontology/`.)
- **Event-driven, not polling.** Never re-enable a fixed-interval orchestrator loop.
- **Numbers are computed, never generated**; findings carry evidence; HITL gates actions.
- **OpenProject plugin = `modules/agentic_ppm`.** Bundled via `Gemfile.modules`; must be in `Gemfile.lock`. Views must namespace `AgenticPpm::AgentRule` (ERB has no module nesting). Menu icons must exist in this OP version (`op-view-list`, not `op-view-list-2`).
- **Rules authoring is novice-friendly** (dropdowns, plain English); the GoRules decision graph is the optional "Advanced" path.

## Where the deep docs live
`agentic-ppm/kyndryl-connector/docs/` — `RULES_ENGINE.md`,
`DECISION_ENGINE_GORULES.md`, `ONTOLOGY_LAYER.md`, `GROUNDING_AND_HALLUCINATION.md`,
`ORCHESTRATION_AND_RULES.md`, `UI_STRATEGY.md`, `SCHEMA_AND_OPENPROJECT_MAPPING.md`.
`agentic-ppm/kyndryl-connector/CLAUDE_MD_FOR_KYNDRAL.md` is the file to install
as `CLAUDE.md` in the Kyndral repo.

## Working here
- agent-runtime: `cd agentic-ppm/agent-runtime && npm run typecheck` (the SessionStart hook installs its deps).
- OpenProject plugin: Ruby in `modules/agentic_ppm/`; can't boot Rails here — rely on the CI smoke test (`.github/workflows/agentic-ppm-smoke.yml`).
