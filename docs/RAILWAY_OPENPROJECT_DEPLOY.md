# Deploy the forked OpenProject (with the agentic_ppm plugin) on Railway

This fork bundles the `modules/agentic_ppm` plugin (Insights + the **Agent
rules** engine). It is compiled into the image at build time — there is no
runtime plugin install. The plugin appears once the image is **built from this
fork** and the database is **migrated**.

## Why the plugin wasn't showing before

`Gemfile.modules` referenced `openproject-agentic_ppm`, but `Gemfile.lock` did
not list it. OpenProject's production build runs bundler **frozen**, so the
plugin was never bundled into running images. That entry is now in the lock
(PATH + DEPENDENCIES + checksums), so a fresh build picks it up.

## Build target & migrations on boot

| Image target (in `docker/prod/Dockerfile`) | Start script | Migrates on boot? |
|---|---|---|
| **slim** (recommended for Railway + managed Postgres) | `./docker/prod/web` | **only if `MIGRATE=true`** |
| all-in-one | `./docker/prod/supervisord` | always (also runs embedded Postgres/Apache — heavier) |

`railway.json` (committed at repo root) points Railway at
`docker/prod/Dockerfile` and starts `./docker/prod/web` (the **slim** path).
Set **`MIGRATE=true`** so every deploy migrates automatically — including the
`agentic_ppm` tables.

> If Railway builds a multi-stage Dockerfile, set the **target stage to `slim`**
> in the service's Build settings (Settings → Build → Target Stage). Otherwise
> use the all-in-one target, which auto-migrates without `MIGRATE`.

## Step by step

1. **Point Railway at this fork.** New Railway service → Deploy from GitHub →
   pick `smithdouglas404/agenticopenproject` → the committed `railway.json`
   selects the Dockerfile build.
2. **Add a Postgres** (Railway Postgres plugin) and a **Redis** if you want the
   worker queue. Wire `DATABASE_URL` from the Postgres service.
3. **Set env vars** (Service → Variables):
   ```
   RAILS_ENV=production
   MIGRATE=true                       # ← migrate on every boot (slim image)
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   SECRET_KEY_BASE=<run: openssl rand -hex 64>
   PORT=8080
   OPENPROJECT_HOST__NAME=<your-railway-domain>
   OPENPROJECT_HTTPS=true
   OPENPROJECT_RAILS__RELATIVE__URL__ROOT=
   # Rules engine: the token the agent-runtime presents to pull rules / post alerts
   # (Administration → Plugins/Settings → Agentic PPM → rules_api_token must match)
   ```
4. **First deploy.** Watch the logs for `Migrating database...` then
   `bundle exec rake db:migrate` — the `agentic_ppm_*` tables are created here.
5. **(Optional) Worker service.** Add a second Railway service from the same
   repo with start command `./docker/prod/worker` (same env, same DATABASE_URL)
   for background jobs.
6. **Seed an admin (first time only).** If the DB is brand new, run a one-off in
   the Railway shell: `MIGRATE=true bundle exec rake db:seed` (or use the
   all-in-one image once, which seeds automatically).

## Verify the plugin is live

- OpenProject → open a project → **Settings → Modules** → tick **Agentic PPM** → Save.
- The project sidebar now shows **Insights** and **Agent rules**.
- Create a rule under **Agent rules**; the agent-runtime pulls it from
  `GET /agentic_ppm/api/rules.json` within `RULES_REFRESH_MINUTES`.

## Wire the agent-runtime (separate Railway service)

The runtime is `agentic-ppm/agent-runtime` in this repo (Node). It evaluates the
rules and fans breaches back. Its rules-relevant env:
```
RULES_ENABLED=1
RULES_SOURCE=openproject
RULES_API_TOKEN=<same token as OpenProject's rules_api_token>
RULES_ZEN_ENABLED=1                # GoRules decision rules
RULES_REFRESH_MINUTES=5
OPENPROJECT_BASE_URL=https://<your-openproject-railway-domain>
OPENPROJECT_API_KEY=<an OpenProject API key>
OPENPROJECT_WEBHOOK_SECRET=<for real-time eval>
FALKORDB_HOST/PORT/GRAPH/PASSWORD  # the FalkorDB service
ANTHROPIC_API_KEY=<…>
```
Then in OpenProject: Administration → Webhooks → add the runtime's
`…/webhooks/openproject` so rules fire the instant a work package changes.

## Troubleshooting

- **Build fails on `bundle install` (frozen):** the lock is out of sync — ensure
  this branch (with the `Gemfile.lock` fix) is what Railway builds.
- **App boots but no Agentic PPM module:** the build predates the lock fix, or
  the target isn't slim/all-in-one — rebuild.
- **`relation "agentic_ppm_agent_rules" does not exist`:** migrations didn't run
  — confirm `MIGRATE=true` (slim) or use all-in-one; check the deploy logs for
  the migration step.
