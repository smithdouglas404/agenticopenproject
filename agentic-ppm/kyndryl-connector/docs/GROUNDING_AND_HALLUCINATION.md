# Is the graph learning & grounding insights? — Honest assessment + how to stop "just an LLM"

Scope: Kyndral-365 DOSv2 (Mastra + A2A, Palantir Foundry ontology as the data
source). This answers two questions directly: (1) is it actually grounded/learning,
or is it "feed data to an LLM and return the answer," and (2) how to reduce
hallucinations so people trust it.

## 1. The honest verdict (no spin)

There are **three tiers**, and they are very different:

| Tier | What it is | Grounded? | Hallucination risk |
|---|---|---|---|
| **Computed metrics** — EVM (CPI/SPI/EAC), risk score (P×I), value realization, capacity | Deterministic math on real Palantir data | ✅ **Fully grounded** | 🟢 None — it's arithmetic |
| **Reactive watcher** — threshold breaches → interventions | Deterministic rules, no LLM | ✅ **Fully grounded** | 🟢 None |
| **Narrative layer** — executive insights, plans, reflections, recommendations | LLM generation given a data context | 🟡 **Loosely grounded** | 🔴 **High** for free-text insights, 🟡 medium for plans/recs |

**So the truthful statement to make to a skeptic:** *"Our numbers are computed, not generated — CPI, schedule variance, risk scores, and value realization are deterministic functions of the source data, with the formulas in code. The LLM does not invent those. Where we use the LLM is to **explain and prioritize** what the numbers mean — and that layer is being hardened with the controls below."*

That is a defensible, honest position. What you must NOT claim yet: that the agents *learn* (they don't — see §3), or that the LLM narrative is verified against the graph (it isn't yet — see §2).

## 2. Where the hallucination risk actually is (and the fixes)

The narrative layer (`executiveInsights.ts`, Deep-agent planning/reflection) feeds real context to the LLM but **does not check the output against reality.** Concretely missing, with the fix for each:

| Gap today | Risk | Fix (in priority order) |
|---|---|---|
| **No entity-existence check** | LLM recommends action on a project/risk that isn't in Palantir | Before emitting any finding, resolve every referenced entity id against Palantir; drop/flag unresolved ones |
| **Computed vs generated not separated** | A made-up "Strategic Readiness: 72%" reads identical to a real CPI | **Two-channel output**: `metrics{}` (computed, never from the LLM) + `narrative{}` (LLM, explains the metrics). UI labels them. The LLM is told to reference metric ids, not invent numbers |
| **No evidence citations** | "3 similar projects succeeded" with nothing to click | Require every finding to carry `evidence:[{entityId, metric, value}]`; render as links. No evidence → not published |
| **No constraint validation** | LLM says "EAC -$5M" or "ship 3 months early" ignoring capacity | After generation, validate against hard bounds (EAC ≥ AC; delay ≤ remaining duration; allocation ≤ capacity). Clip or reject violations |
| **No cross-agent contradiction check** | PMO "add headcount" vs FinOps "freeze hiring" both fire | A reconciliation pass over the open findings flags conflicting recommendations for the same entity before they reach a human |
| **No confidence/abstention** | LLM always answers, even with thin data | Carry a confidence score; below a threshold, the agent says "insufficient data" instead of guessing (you already store confidence on facts — enforce it) |

These are the difference between "LLM with a dashboard" and "an agent that reasons over a grounded portfolio." None require new infra — they're a validation layer around the existing LLM calls.

## 3. Is it learning? — No, not yet. Here's the truth and the fix.

What exists: agents **broadcast facts** to Mem0 (with confidence + timestamp) and **recall** them to avoid repeating work. That's *memory*, not *learning*.

What's missing for real learning (and it's the single highest-trust feature you can add):
- **Outcome tracking.** Agents store predictions ("value at risk", "forecast EAC") but **never compare them to what actually happened.** The `actual_outcome` path is not wired.
- **The loop to add:** when a project/PI closes (or on a schedule), join each stored prediction to the realized value → compute accuracy per agent + per finding-type → **store it** → **weight future findings by historical accuracy** (favor the agents/patterns that have been right).

Once that loop runs, you can say something no "LLM wrapper" can: *"This agent's overdue-risk calls have been 84% accurate over the last 40 closed items"* — that is provable learning, and it's the strongest anti-"it's just an LLM" argument you have.

## 4. The ontology is loaded but not reasoning

The Smith-Clarity mega-ontology (1,870 triples, the `pm:` spine + SAFe/PMBOK/PRINCE2/K360 dialects) is loaded into an N3 store but used only for **static lookups** — there's **no OWL reasoner and no SPARQL inference at runtime.** Agents read structured data from Palantir, not the triple store.

That's fine for now (the property-graph + deterministic detectors do the work), but two cheap upgrades make the ontology *earn its keep* and improve grounding:
1. **Materialize the spine mappings** (already done in the agent-runtime `mapping.ts`) so every source's types resolve to canonical `pm:`/`safe:` classes — this is what lets OpenProject, Jira, Planview etc. be reasoned over uniformly.
2. **Encode the K360 inference classes as Cypher/queries** (OrphanedProject, CostAnomaly, LowReadinessInitiative) instead of OWL rules — explicit, auditable detections (this is exactly what the agent-runtime detectors already do, and they're *more* defensible than a reasoner's opaque derivations).

## 5. What to tell people (the trust narrative)

> "The portfolio metrics are **computed**, not generated — the formulas are in code and run on the source data, so the numbers can't be hallucinated. The agents reason over a **graph world-model** (entities, dependencies, OKR alignment), each finding **cites the specific work items and metrics** it's based on, recommendations are **validated against real constraints** (capacity, budget, schedule), and a **human approves** before anything acts. Over time the system **tracks whether its predictions came true** and weights its future calls by that track record. The LLM's job is to explain and prioritize — not to invent the facts."

Every clause in that sentence corresponds to a control above. Ship the §2 validation layer + the §3 outcome loop and the sentence becomes literally true.

## 6. Build order (highest trust-per-effort first)
1. **Two-channel output** (computed `metrics{}` vs LLM `narrative{}`) + **evidence citations** — small, makes it visibly grounded immediately.
2. **Entity-existence + constraint validation** after every LLM finding — kills the worst hallucinations.
3. **Outcome tracking loop** (predictions → actuals → accuracy → weighting) — the real "learning" claim.
4. **Cross-agent contradiction check** before findings reach a human.
5. **Confidence-gated abstention** ("insufficient data") instead of always answering.
