# Where do I code? (and how the pieces fit)

Three **separate** services, **one** product. Like rooms in one restaurant —
separate kitchens, one establishment. Wire them with env vars; never merge them
into one codebase.

## The map

| Service | What it is | Code here? |
|---|---|---|
| **Kyndral-365** (its own repo) | The dining room — the UI users see and click. **The product.** | **Yes — almost always.** |
| **OpenProject** (`agenticopenproject` root) | The pantry — where project/work data physically lives. Has the `agentic_ppm` plugin (rules authoring). | Rarely. Configure via its own screens / the plugin. |
| **agent-runtime** (`agenticopenproject/agentic-ppm/agent-runtime`) | The brain — runs ALL the agents over the FalkorDB graph; owns findings, HITL, learning, the rules evaluator. | Only to change agent/rules behavior. |
| **FalkorDB** (managed) | The ledger the brain reads. | No. |

## "Which repo do I open?" — the rule

- **Anything users see or do** (screens, dashboards, agentic UI, OKRs, reports,
  chat) → **Kyndral-365.** ~90% of your work.
- **How agents think / the rules engine / OpenProject plugin or data model** →
  **agenticopenproject.** Occasional.
- **The actual project data** → **OpenProject's own UI.** No code.

**Default: open Kyndral-365 and build there.**

## How they talk (so you don't have to merge them)

Over HTTP, via env vars:
- Kyndral → OpenProject: `OPENPROJECT_BASE_URL`, `OPENPROJECT_API_KEY`
- Kyndral → agent-runtime: `AGENT_RUNTIME_URL` (+ `AGENT_RUNTIME_TOKEN`)
- agent-runtime → OpenProject: `OPENPROJECT_BASE_URL`, `OPENPROJECT_API_KEY`
- agent-runtime → FalkorDB: `FALKORDB_HOST/PORT/GRAPH/PASSWORD`

All four live in **one Railway project** (one canvas). Keep them there — separate
services, shared private network. Don't split into multiple Railway projects;
don't collapse into one service.

## Want to vibe across both repos at once?

You don't need to merge them. When you start a Claude Code session, the repo
picker lets you select **both Kyndral-365 and agenticopenproject** — one
session edits both, but they stay separately deployable. The `CLAUDE.md` +
SessionStart hook in each repo means any session knows this architecture
automatically.

## The thing that broke before (don't repeat it)

The entire OpenProject monorepo (16k files) was once vendored *into* Kyndral.
It broke the build for days. **Never vendor one service's source into another** —
the CI guard `no-vendor-openproject.yml` now blocks it.
