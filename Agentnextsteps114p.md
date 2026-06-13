# Agent next steps — master task list (captured 17:14, session 114p)

Status of the whole build, what I'm doing autonomously now, and what needs
**your access** (Railway / the Kyndral repo) when you're back.

Legend: ✅ done · 🔨 building now (autonomous, this session) · 👤 needs YOUR
session (Kyndral repo / Railway — I can't reach those) · ⏭ later.

---

## ✅ Done (live on `agenticopenproject` main)
- OpenProject fork deployable on Railway (Gemfile.lock plugin, VOLUME, Zeitwerk,
  icon, migrate-on-boot fixes).
- `modules/agentic_ppm` plugin: novice-friendly **rules authoring** (dropdowns,
  plain English) + GoRules JDM "Advanced" path; `rules.json` / `alerts.json` API.
- agent-runtime = **grounding layer** (no LLM brain): FalkorDB graph, computed
  metrics, rules engine (GoRules ZEN), findings/HITL, OpenProject write-back.
- **Connection is GREEN** (OpenProject ✓ / FalkorDB ✓ / Memory ✓) after the
  fresh API key.
- Mastra deep agents in Kyndral = **the brain** (untouched, Mem0 + Letta + a2a).
- `AgentConsole.tsx` — the runtime console rebuilt as a **native Kyndral React
  component** (reads `/api/agent/*`). Drop-in ready.
- Guardrails: root `CLAUDE.md`, SessionStart hook, CI plugin/anti-vendor guards,
  Kyndral un-vendor recovery doc, corrected Kyndral `Dockerfile.production`
  (Node+npm).

## 🔨 Building now — the ontology-as-universal-mapper foundation (my side, autonomous)
These land as real runtime code + Kyndral drop-ins + docs on `agenticopenproject`:
1. **Schema discovery** — `GET /api/openproject/schema`: every OpenProject
   attribute incl. **custom fields**, with type. Raw material for mapping.
2. **Custom-attribute ingestion** — projector writes arbitrary OpenProject
   attributes (incl. custom fields) onto graph nodes (today only standard fields).
3. **Ontology properties** — `GET /api/ontology/properties`: the spine
   properties to map onto.
4. **Mapping model (stored as data)** — `source field → ontology property →
   transform → widget`, served at `/api/mapping` (+ defaults seeded from spine).
5. **Widget catalog** — `/api/widgets`: attribute-type → valid widget types
   (number→KPI/gauge, date→timeline, enum→badge, hierarchy→tree, relation→graph…).
6. **Kyndral drop-ins:** `MappingStudio.tsx` (discover→map→widget→preview→publish),
   a `WidgetRenderer` registry (attribute-type → React widget), and a
   `agentRuntimeClient` for Mastra `DeepAgentBase` to pull grounded facts.
7. **Docs:** `ONTOLOGY_MAPPING_STUDIO.md`, `WIDGET_CATALOG.md`,
   `MASTRA_GROUNDING_INTEGRATION.md`.

## 👤 Needs YOUR session (Kyndral repo + Railway — I have no access)
**Make the agents operate (wire Mastra → grounding):**
1. In Kyndral, add the `agentRuntimeClient` and call it from `DeepAgentBase`:
   before reasoning, pull `/api/agent/metrics` + the relevant graph slice +
   rule results (so numbers are grounded, not invented); publish findings back.
   (Drop-in + exact steps in `MASTRA_GROUNDING_INTEGRATION.md`.)
2. Mount `<AgentConsole/>` where the old console lived (e.g. AgentCommandCenterPage).
3. Mount the `/api/agent/*` proxy routes (`agentFindings.routes.ts`) +
   `/api/openproject/*` writeback routes if not already.
4. Apply the corrected `Dockerfile.production` (fixes the yellow Kyndral build).

**Deploy / config (Railway):**
5. Add the OpenProject **webhook** → `…/agent-runtime…/webhooks/openproject`
   (real-time agent firing).
6. Set `LETTA_API_KEY` on agent-runtime so agents are **stateful**.
7. Set `RULES_API_TOKEN` (matching the OpenProject plugin's `rules_api_token`)
   so the rules agent pulls rules.
8. Enable the **Agentic PPM** module per-project + grant `view/manage_agent_rules`,
   then author your first rule.
9. Rotate the API tokens that were pasted in chat (the dead `33773…` and the
   Railway token `fecff7…`).

## ⏭ Later (after the foundation)
- Generalize the mapping studio to Jira / ADO / ServiceNow / **MCP** sources
  (each = a new adapter to the spine; MCP resources→objects, MCP tools→actions).
- Bidirectional edit widgets (write-back) per attribute.
- ML-suggested thresholds from the learning loop.
- Rename `/api/palantir/ontology/*` → `/api/ontology/*` (see `ONTOLOGY_LAYER.md`).

---

**Architecture truth (do not regress):** ontology (FalkorDB) is the **hub**;
every API + MCP maps **once** to it; every consumer (Mastra agents, widgets,
UI) reads **once** from it. N+M, not N×M. The Mastra agents are the brain; the
agent-runtime is the grounded data layer they call.
