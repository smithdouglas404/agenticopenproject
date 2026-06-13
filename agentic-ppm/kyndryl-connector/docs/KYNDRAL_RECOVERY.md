# Kyndral-365 recovery — un-vendor OpenProject, restore the working model

## What went wrong (from the Kyndral repo's own git history)

- Kyndral-365 was a clean working app for ~1,120 commits (Jan 6 → Jun 12). Its
  last clean commit is **`681c097b`** — *"harden two-way OpenProject sync"* — at
  which point Kyndral **already had working two-way OpenProject integration over
  the API**, as a separate service.
- On Jun 13 01:02, commit **`6db740ed`** *"Monorepo: vendor the OpenProject fork
  and agent-runtime into this repo"* added **16,284 files / 1.86M lines** of the
  entire OpenProject monorepo into Kyndral.
- Every commit after that fought OpenProject's Angular/Rails build *inside*
  Kyndral. That's the breakage.

**The working model = Kyndral ↔ agent-runtime ↔ OpenProject as three separate
services talking over HTTP.** Vendoring was the wrong move.

## The recovery (validated — these exact steps were simulated against the repo)

```bash
# in the Kyndral-365 repo
git fetch origin
git branch backup/pre-recovery origin/main          # safety net (keeps everything)
git checkout main
git reset --hard 681c097b                            # last clean Kyndral

# Re-apply the 4 genuine fixes your sessions made after the vendoring
# (the rest were OpenProject-build firefighting and are now irrelevant):
git cherry-pick -x 442b918f   # #15 OpenAI client optional/lazy (clean)
git cherry-pick -x c19c2add   # #14 agent-runtime sole agent + doc prune
#   -> CONFLICT in CLAUDE.md only. Resolve by taking the incoming version:
git checkout --theirs CLAUDE.md && git add CLAUDE.md && git cherry-pick --continue --no-edit
git cherry-pick -x c0ac891a   # #16 UI ontology route -> FalkorDB, remove Palantir
#   -> may CONFLICT in docs/PALANTIR_TO_FALKORDB.md only (a doc). Take incoming:
#   git checkout --theirs docs/PALANTIR_TO_FALKORDB.md && git add ... && git cherry-pick --continue --no-edit
git cherry-pick -x 510f761c   # #19 auto-provision DB schema on deploy (clean)

git push --force-with-lease origin main
```

**Both conflicts are documentation files** — no code conflicts. The code
changes (server ontology route → FalkorDB, OpenAI lazy-init, railway.json) all
apply cleanly. If the FalkorDB cutover #16 needs the agent-runtime URL, it reads
it from `AGENT_RUNTIME_URL` / the OpenProject API base — no vendoring needed.

## After the recovery — restore the 3-service deploy

Kyndral is a Node app again (no Rails/Angular OpenProject build). On Railway:
- **Kyndral service**: build from `Dockerfile.production` (the Node/Vite app), NOT
  the OpenProject Dockerfile. Remove any OpenProject build steps the firefighting
  commits added.
- **OpenProject**: deploys from `agenticopenproject` (its own service) — unchanged.
- **agent-runtime**: deploys from `agenticopenproject/agentic-ppm/agent-runtime`
  (its own service) — unchanged.
- Wire them with env: Kyndral gets `OPENPROJECT_BASE_URL`, `OPENPROJECT_API_KEY`,
  `AGENT_RUNTIME_URL` pointing at those services.

## Prevent recurrence (this is the real fix for "agents don't read CLAUDE.md")

Two mechanical guards that don't depend on a model choosing to read a doc:

1. **SessionStart hook** — copy `ci/kyndral-session-start.sh` to
   `.claude/hooks/session-start.sh` in Kyndral and register it in
   `.claude/settings.json` (see `ci/kyndral-settings.json`). Its stdout is
   injected into **every** session, so the architecture rules load whether or
   not the agent opens CLAUDE.md.
2. **Anti-vendor CI guard** — copy `ci/no-vendor-openproject.yml` to
   `.github/workflows/` in Kyndral. It **fails the build** if the OpenProject
   monorepo (a root `config.ru`/`Gemfile`, or a huge file-count spike) is ever
   committed again. The wrong merge becomes impossible to merge.

Install `CLAUDE_MD_FOR_KYNDRAL.md` as Kyndral's root `CLAUDE.md` too.
