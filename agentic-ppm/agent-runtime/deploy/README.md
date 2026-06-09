# Deploying the Agentic PPM stack

The stack is four services:

| Service | What it is | Image / source |
|---|---|---|
| **openproject** | Source of truth + UI | `openproject/openproject:15` (all-in-one) |
| **falkordb** | Graph world-model | `falkordb/falkordb:latest` |
| **graphiti-mcp** | Temporal memory (on FalkorDB) | Graphiti MCP server (verify tag) |
| **agent-runtime** | This sidecar | built from `agentic-ppm/agent-runtime/` |

## Recommendation: Railway (hosted) over local docker-compose

Since you already use Railway, **host it on Railway** rather than running compose
locally. It gives a persistent, publicly-reachable OpenProject the sidecar (and I,
for smoke tests) can hit, and matches your infra. Use local compose only for
throwaway dev.

**Important:** Railway does **not** run `docker-compose up` — it deploys one
*service* per block. So `deploy/docker-compose.yml` is the source of truth; on
Railway you recreate each block as a Railway service:

1. **OpenProject** — New Service → Docker image `openproject/openproject:15`
   (or use Railway's OpenProject template if present). Add a **Postgres** plugin
   and set `DATABASE_URL`, plus `OPENPROJECT_SECRET_KEY_BASE`,
   `OPENPROJECT_HOST__NAME=<public domain>`, `OPENPROJECT_HTTPS=true`.
   Then: create an API key (My Account → Access tokens), a project with identifier
   `agent-alerts`, a WP type `Agent Alert`, and custom fields `sync_source` +
   `alert_severity`.
2. **FalkorDB** — New Service → Docker image `falkordb/falkordb:latest`. Expose it
   on the private network; note host/port for the sidecar.
3. **graphiti-mcp** — New Service → the Graphiti MCP image (confirm tag against
   getzep/graphiti). Env: FalkorDB connection + an LLM key. Expose `:8000/sse`.
4. **agent-runtime** — New Service → deploy from this repo, **Root Directory**
   `agentic-ppm/agent-runtime` (it has a Dockerfile). Set the env from
   `.env.example`, pointing `FALKORDB_HOST`, `GRAPHITI_MCP_URL`,
   `OPENPROJECT_BASE_URL`, and the API/Anthropic keys at the services above.

Finally, in OpenProject → Administration → Webhooks, add:
`https://<agent-runtime-domain>/webhooks/openproject` with the shared secret and
events `work_package:created/updated`, `project:created/updated`.
`npm run seed:webhook` prints this checklist with your configured values.

### Seed the graph (run once before going live)

Before the first webhook fires, backfill the graph from existing OpenProject
data so the agent reasons over a populated world-model on day one:

```bash
npm run sync:backfill   # pages through all projects + work packages; idempotent
```

## Is "one or two" better — OpenProject's own setup vs ours?

The OpenProject Docker setup that's safe to run is the **all-in-one
`openproject/openproject` image** (or the maintained `opf/openproject-docker-compose`
repo). This repository's root `docker-compose.yml` is **core-development only** —
it's guarded by `LOCAL_DEV_CHECK` and errors out telling you the runnable compose
moved elsewhere. So: use the all-in-one image for the instance, and this
`deploy/` stack for everything around it.

## Local (dev) quick start

```bash
cd agentic-ppm/agent-runtime/deploy
# export OPENPROJECT_BASE_URL, OPENPROJECT_API_KEY, ANTHROPIC_API_KEY (+ a Graphiti LLM key)
docker compose up --build
```
