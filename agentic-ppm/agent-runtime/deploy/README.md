# Deploying the Agentic PPM stack

The stack is four services:

| Service | What it is | Image / source |
|---|---|---|
| **openproject** | Source of truth + UI | `openproject/openproject:15` (all-in-one) |
| **falkordb** | Graph world-model | `falkordb/falkordb:latest` |
| **graphiti-mcp** | Temporal memory (on FalkorDB) | Graphiti MCP server (verify tag) |
| **agent-runtime** | This sidecar | built from `agentic-ppm/agent-runtime/` |

## ⚠️ Do NOT attach the repo ROOT to Railway

This repository's root is the **OpenProject Rails monorepo**. If you attach the
root, Railway auto-detects a Rails app (`Gemfile` + `config.ru` + `Procfile`) and
creates **one service per Procfile process** — `web`, `worker`, `backup`, `check`
— trying to build OpenProject from source. That is NOT this stack, and not what
you want. There is no `railway.json` at the root, so nothing overrides that.

**The fix:** deploy OpenProject from its **prebuilt image** (below), and deploy
the sidecar from the repo with **Root Directory = `agentic-ppm/agent-runtime`**.
That subdir has its own `Dockerfile` + `railway.json` (builder=DOCKERFILE,
healthcheck `/health`), so Railway builds just the Node sidecar — not the Rails
tree. Delete the auto-created `web`/`worker`/`backup`/`check` services.

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

### Verify + seed (run on the Railway sidecar service)

The sidecar must reach OpenProject + FalkorDB + Graphiti on Railway's private
network, so run these from the **sidecar service** shell (not a dev sandbox):

```bash
npm run preflight       # ✅/❌ report: are OpenProject, FalkorDB, Graphiti reachable?
npm run smoke           # end-to-end: create a throwaway WP -> project -> assert in graph -> cleanup
npm run sync:backfill   # seed the graph from existing OpenProject data; idempotent
```

Run `preflight` first; once it's all green, `smoke` proves the round-trip and
`sync:backfill` seeds history before the first real webhook fires.

**No shell access?** Set env var `PREFLIGHT_ON_BOOT=1` on the sidecar service and
redeploy — it logs the same ✅/❌ dependency report to the deploy logs at startup,
then starts normally. (Or set Custom Start Command to `npm run preflight; npm start`.)

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
