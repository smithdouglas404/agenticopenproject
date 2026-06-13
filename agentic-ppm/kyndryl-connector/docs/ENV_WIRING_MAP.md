# Env wiring map — which variable on which service points where

Four services, one Railway project. This is every variable that makes them talk
to each other. Set these and the console's OpenProject pill goes green, the
agents become stateful, and rules/agents fire on real changes.

## 1) OpenProject service (built from `agenticopenproject`)
```
RAILS_ENV=production
MIGRATE=true                         # ← creates agentic_ppm_* tables on boot
DATABASE_URL=${{Postgres.DATABASE_URL}}
SECRET_KEY_BASE=<openssl rand -hex 64>
OPENPROJECT_HOST__NAME=<openproject-...up.railway.app>
OPENPROJECT_HTTPS=true
PORT=8080
# Rules engine: token the agent-runtime presents to pull rules / post alerts.
# Also set in Administration → Plugins/Settings → Agentic PPM → rules_api_token
```
Then in the OpenProject UI: per project → **Settings → Modules → tick Agentic PPM**,
and grant the role **view/manage_agent_rules** (+ recommendations) so the menus show.

## 2) agent-runtime service (built from `agenticopenproject/agentic-ppm/agent-runtime`)
```
OPENPROJECT_BASE_URL=https://<openproject-...up.railway.app>
OPENPROJECT_API_KEY=<API token from OpenProject: My account → Access tokens>
OPENPROJECT_WEBHOOK_SECRET=<shared secret>      # HMAC for inbound webhook
FALKORDB_HOST=<falkordb host>                    # the FalkorDB service
FALKORDB_PORT=6379
FALKORDB_GRAPH=agentic_ppm
FALKORDB_PASSWORD=<if set>
ANTHROPIC_API_KEY=<claude key>
CONSOLE_TOKEN=agentic-ppm-console-2026           # guards /console + /api
# Rules engine (pull + post-back):
RULES_ENABLED=1
RULES_SOURCE=openproject
RULES_API_TOKEN=<same as OpenProject rules_api_token>
RULES_ZEN_ENABLED=1                              # GoRules decision rules
# Autonomy (agents):
AGENTS_EVENT_DRIVEN=1                            # fire on change (default)
AGENTS_PROACTIVE=1                               # opportunity reflection on change + a2a
AGENTS_PROACTIVE_SCAN_MIN=0                      # 0 = NO cron (default); >0 = opt-in sparse scan
# Stateful agents (so they REMEMBER — the proactive part):
LETTA_API_KEY=<letta cloud key>   # or LETTA_BASE_URL=<self-hosted>
LETTA_MODEL=anthropic/claude-sonnet-4-20250514
MEMORY_PROVIDER=falkor            # falkor | mem0 | letta | none
# (optional) MEM0_API_KEY=<…> if MEMORY_PROVIDER=mem0
```
Without `LETTA_*` the agents still reason, just statelessly per change. With it,
they accumulate memory and get proactively smarter.

## 3) Kyndral-365 service (built from `Dockerfile.production`)
```
OPENPROJECT_BASE_URL=https://<openproject-...up.railway.app>
OPENPROJECT_API_KEY=<API token>
AGENT_RUNTIME_URL=https://<agent-runtime-...up.railway.app>
AGENT_RUNTIME_TOKEN=<same as agent-runtime CONSOLE_TOKEN>
# + Kyndral's own app vars (DATABASE_URL, session secret, etc.)
```
Kyndral reads agent output via `/api/agent/*` (proxied to the runtime) and pushes
edits back via `openProjectWriteback`.

## 4) FalkorDB service
Managed; just needs to be reachable on the private network by the agent-runtime
(host/port/password above). On Railway the agent-runtime sets
`dns.setDefaultResultOrder('ipv6first')` automatically so the private host resolves.

## The webhook (real-time, event-driven agents)
OpenProject → **Administration → Webhooks** → add
`https://<agent-runtime-...>/webhooks/openproject` with `OPENPROJECT_WEBHOOK_SECRET`.
This is what makes agents fire the instant a work package changes.

## Quick health check (no token-sharing needed)
`GET https://<agent-runtime-...>/api/status?token=<CONSOLE_TOKEN>` →
each dependency's `ok` + `detail`. OpenProject `ok:false` 401 = bad key;
`fetch failed` = bad URL.
