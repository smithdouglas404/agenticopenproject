# 00 — Vision & Principles

## The vision

Build an **Agentic PPM** layer on OpenProject in which several autonomous agents
continuously observe the portfolio, reason over a shared semantic model, learn over
time, and deliver **recommendations and insights** to the people running the portfolio —
without waiting to be asked.

Today, a PPM tool answers *"what is the status?"*. We want a system that answers
*"which strategic objectives are funded by over-budget projects that also have low
adoption readiness, and what should we do about it?"* — and raises that as a typed,
auditable recommendation before a human thinks to look.

## Where this comes from

The Smith Clarity ontology (vendored under `agentic-ppm/ontology/`) was authored for an
enterprise deployment whose live source of truth was **a Foundry-style ontology service**, driving an
**11-agent system across 9 domains**. This project keeps the ontology and the agent
model intact and **substitutes OpenProject for Foundry as the source of truth**. The
intellectual core — a neutral PM spine with SAFe/PMBOK/PRINCE2 dialects and the K360
agent model — carries over unchanged.

## Principles (non-negotiables)

### 1. OpenProject is the single source of truth
- All durable portfolio facts live in OpenProject (projects, work packages, versions,
  relations, custom fields, time entries, budgets).
- Agents never hold a competing system of record. The knowledge graph is a
  **projection** of OpenProject (plus derived/temporal facts), not a parallel truth.
- Every agent recommendation is written **back into OpenProject** so it is visible,
  governable, and auditable in the tool people already use.

### 2. SAFe 6.0 is the well-architected reference model
- The ontology's framework-neutral spine (`pm:`) is the lingua franca; **SAFe 6.0**
  (`safe:`) is the reference dialect every other methodology is mapped onto.
- A team running Scrum, Kanban, PMBOK, or PRINCE2 still rolls up into one SAFe-shaped
  portfolio view because the **bridging axioms** project every dialect onto the spine.
- "Well-architected" means: hierarchy (Portfolio → Value Stream → ART → PI → Team →
  Epic → Feature → Story → Enabler), Lean Portfolio Management, WSJF, and flow are the
  canonical structure; other methods are expressed *in terms of* it.

### 3. The ontology is the agents' world model — not just documentation
- Agents read the OWL model as their schema and their reasoning substrate.
- Derived classes (`OrphanedProject`, `CostAnomaly`, `TransformationFatigue`,
  `LowReadinessInitiative`, …) let agents *infer* problems instead of hand-coding every
  check.
- The model is standard W3C OWL, so it outlives any single tool and any single agent
  framework.

### 4. Autonomy with accountability
- Agents run **on events** (OpenProject webhooks) and **on a schedule** (periodic
  reasoning cycles). They are not request/response chatbots.
- Every output is a typed `k360:AgentFinding` / `k360:Intervention` with a
  **source agent, confidence, provenance, and temporal validity**
  (`valid_from`/`valid_to`, version, audit trail).
- Agents **recommend**; humans (or explicitly governed policies) **decide**. Write-back
  to OpenProject is, by default, a *proposal* a human approves — not a silent mutation.

### 5. Learning over time
- Agents keep `k360:AgentMemory`; the temporal knowledge graph records how facts change,
  enabling leading indicators ("budget variance is *accelerating*") rather than
  lagging snapshots.
- Feedback on recommendations (accepted / dismissed / overridden) is captured and feeds
  back into agent behavior.

### 6. Multi-agent, not monolith
- Nine specialized domains (Value Realization, Strategic PMO, Transformation, FinOps,
  OKR, Governance, Planning, OCM, Notification) plus agent-operations plumbing.
- Agents collaborate via **A2A messages** (`k360:A2AMessage`) and a Notification
  Orchestrator that deduplicates and prioritizes before anything reaches a human.

## What success looks like (Phase-1 horizon)

- A portfolio manager opens OpenProject and sees an **Insights inbox**: ranked,
  explained, dismissible recommendations sourced from the agents.
- Each insight links to the exact work packages/projects it concerns and shows *why*
  (the rule or signal that produced it) and *how confident* the agent is.
- Methodology-diverse teams roll up into one SAFe-shaped portfolio view with no manual
  reconciliation.

## Explicit non-goals (for now)

- Replacing OpenProject's own UI for day-to-day task management.
- Fully autonomous, unsupervised mutation of the portfolio (agents propose; governance
  gates anything that writes).
- Boiling the ocean: we ship a **vertical slice of 4 agents** first (see
  `04-agent-roster.md`), not all 9 at once.
