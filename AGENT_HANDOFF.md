# AGENT HANDOFF — get the agents operating 100% autonomous

Paste the **"START HERE prompt"** below into a **new Claude Code session** that
has **both** repos selected in the repo picker:
`smithdouglas404/agenticopenproject` **and**
`smithdouglas404/Kyndral-365-Agentic-VRO-Framework-DOSv2`.
(Both repos are needed: the drop-ins live in `agenticopenproject`; they get
installed into Kyndral.)

---

## START HERE prompt (copy everything in this block)

> You are continuing a build. Architecture (do not change it): **three
> deployables** — OpenProject (datastore + rules authoring), **agent-runtime**
> (grounding/data layer: FalkorDB graph, computed metrics, rules engine,
> findings/HITL — NO LLM reasoning), and **Kyndral-365** (the UI; its **Mastra
> deep agents are the brain**, with Mem0 + Letta). They integrate over HTTP;
> never vendor one repo into another.
>
> Current state: OpenProject ↔ agent-runtime ↔ FalkorDB is **connected and
> green**. The agent-runtime exposes `/api/*` (findings, metrics, rules,
> roster, status, project-status, openproject/schema, ontology/properties,
> widgets, mapping). Ready-to-install drop-ins live in
> `agenticopenproject/agentic-ppm/kyndryl-connector/`.
>
> Do these in the **Kyndral repo**, committing + opening PRs:
> 1. **Wire the Mastra agents to grounding** (this is "agents operating"):
>    copy `client/src/openproject/agentRuntimeClient.ts` into Kyndral and follow
>    `docs/MASTRA_GROUNDING_INTEGRATION.md` — in `server/agents/deep/DeepAgentBase.ts`,
>    before reasoning, call the runtime for grounded facts (`getMetrics()`,
>    `getRules()`, graph slice) and feed them into the prompt (cite metric ids,
>    never invent numbers); publish conclusions back via `publishFinding()`.
>    Keep Mem0 + Letta as the agents' memory. Do NOT re-add the
>    ContinuousOrchestrator 15s loop — agents fire on real change + a2a.
> 2. **Mount the proxy + UI**: add `server/routes/agentFindings.routes.ts`
>    (the `/api/agent/*` proxy, env `AGENT_RUNTIME_URL` + `AGENT_RUNTIME_TOKEN`);
>    render `<AgentConsole/>` where the old console lived; add `<MappingStudio/>`
>    as a new admin screen; copy `WidgetRenderer.tsx`.
> 3. **Fix the build**: replace Kyndral's `Dockerfile.production` with
>    `agentic-ppm/kyndryl-connector/ci/Dockerfile.production` (Node+npm, not Bun).
> 4. Confirm `/api/agent/status` shows OpenProject `ok:true` from the Kyndral side.
>
> Reference docs (in `agenticopenproject/agentic-ppm/kyndryl-connector/docs/`):
> `MASTRA_GROUNDING_INTEGRATION.md`, `ONTOLOGY_MAPPING_STUDIO.md`,
> `WIDGET_CATALOG.md`, `AGENT_CONSOLIDATION.md`. Master task list:
> `agenticopenproject/Agentnextsteps114p.md`.

---

## Then, in the browsers (you, not the agent — needs Railway/OpenProject)
- agent-runtime service env: set **`LETTA_API_KEY`** (stateful agents) and
  **`RULES_API_TOKEN`** (matches the OpenProject plugin's `rules_api_token`).
- OpenProject → Administration → **Webhooks** → add
  `https://<agent-runtime-host>/webhooks/openproject` (real-time firing).
- OpenProject → a project → Settings → **Modules → enable Agentic PPM**; grant
  the role `view/manage_agent_rules`; author your first rule.
- **Rotate** the tokens pasted in chat (dead OpenProject `33773…`, Railway `fecff7…`).

## What "100% autonomous" means once the above is done
Mastra agents react to OpenProject changes (via the webhook/change-feed) and to
each other (a2a), pulling grounded facts from the agent-runtime so their numbers
are computed-not-invented, remembering via Mem0+Letta, and surfacing
findings/recommendations into `AgentConsole` for HITL — no cron, no orchestrator.
