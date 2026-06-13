#!/bin/bash
# SessionStart hook — forces the architecture guardrails into EVERY session's
# context (so it never depends on the model choosing to read CLAUDE.md) and
# installs the agent-runtime deps so typecheck/smoke work.
#
# A SessionStart hook's stdout is injected into the session context by the
# harness. We print the non-negotiable rules here; the full detail is in
# CLAUDE.md + agentic-ppm/kyndryl-connector/docs/.
set -euo pipefail

cat <<'GUARDRAILS'
================ AGENTICOPENPROJECT — ARCHITECTURE GUARDRAILS ================
THREE SEPARATE DEPLOYABLES — integrate over APIs, never vendor code:
  1) OpenProject fork (this repo root, Rails) + modules/agentic_ppm plugin
  2) agent-runtime (agentic-ppm/agent-runtime, Node) — FalkorDB graph + agents
  3) Kyndral-365 (SEPARATE repo) — the UI; talks to 1 & 2 over HTTP

🚫 HARD RULE: NEVER vendor the OpenProject monorepo (16k+ files) into Kyndral
   or any app repo. It broke the Kyndral build for days. Integrate via API.
   (CI guard enforces this — do not bypass.)

OTHER LOAD-BEARING RULES:
 - FalkorDB is the ONLY ontology backend. No Palantir/Foundry.
 - Event-driven, not polling. No fixed-interval orchestrator loops.
 - Numbers are computed (not LLM-generated); findings cite evidence; HITL gates actions.
 - OpenProject plugin = modules/agentic_ppm: must be in Gemfile.lock; ERB views
   must namespace AgenticPpm::AgentRule; menu icons must exist (op-view-list).
 - Full architecture + docs: ./CLAUDE.md and agentic-ppm/kyndryl-connector/docs/
==============================================================================
GUARDRAILS

# Install agent-runtime deps so `npm run typecheck` / smoke scripts work.
# Idempotent + bounded; only runs when deps are missing.
RT_DIR="${CLAUDE_PROJECT_DIR:-.}/agentic-ppm/agent-runtime"
if [ -f "$RT_DIR/package.json" ] && [ ! -d "$RT_DIR/node_modules" ]; then
  echo "[session-start] installing agent-runtime deps..."
  ( cd "$RT_DIR" && npm install --no-audit --no-fund ) || \
    echo "[session-start] agent-runtime npm install failed (non-fatal)"
fi
