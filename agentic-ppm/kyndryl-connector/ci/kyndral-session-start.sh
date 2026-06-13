#!/bin/bash
# Kyndral-365 SessionStart hook. Its stdout is injected into EVERY session's
# context by the harness, so the architecture loads whether or not the agent
# opens CLAUDE.md. Copy to .claude/hooks/session-start.sh and register it in
# .claude/settings.json (see ci/kyndral-settings.json).
set -euo pipefail
cat <<'GUARDRAILS'
================ KYNDRAL-365 — ARCHITECTURE GUARDRAILS ================
THREE SEPARATE DEPLOYABLES — integrate over HTTP APIs, NEVER vendor code:
  1) Kyndral-365 (THIS repo) — the UI/server. Talks to 2 & 3 over HTTP.
  2) OpenProject (separate repo agenticopenproject) — datastore; APIv3.
  3) agent-runtime (agenticopenproject/agentic-ppm) — FalkorDB graph + agents.

🚫 HARD RULE: NEVER vendor the OpenProject monorepo into this repo. Doing it once
   added 16k files and broke the build for days. Integrate via API only.
   (.github/workflows/no-vendor-openproject.yml enforces this.)

 - FalkorDB is the only ontology backend (server/FalkorOntologyDataProvider.ts). No Palantir/Foundry.
 - Numbers computed not generated; findings cite evidence; HITL gates actions.
 - Full integration guide + rules: ./CLAUDE.md
=======================================================================
GUARDRAILS

# Install Node deps so the app builds/tests in-session (idempotent).
if [ -f package.json ] && [ ! -d node_modules ]; then
  npm install --no-audit --no-fund || echo "[session-start] npm install failed (non-fatal)"
fi
