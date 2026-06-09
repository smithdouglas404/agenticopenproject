# 04 — Agent Roster

The K360 module (`modules/k360.ttl`) models a multi-agent system across **nine domains**
plus agent-operations plumbing. Each agent reads the knowledge graph as its world model,
reasons (rules + LLM), and emits typed `k360:AgentFinding` / `k360:Intervention` outputs
that surface in the OpenProject Insights inbox.

## 1. The nine domains (from the ontology)

| # | Domain (agent) | Ontology anchor | What it reasons about |
|---|---|---|---|
| 1 | **VRO — Value Realization** | `k360:Investment, Benefit, BenefitRealization, ValueMetric, BusinessOutcome` | ROI projections, benefit realization vs. plan, value leakage |
| 2 | **Strategic PMO** | `k360:Project, FlowMetric, ScheduleVariance, DeliveryRisk, ResourceAllocation` | delivery status, flow, schedule variance, delivery risk |
| 3 | **TMO — Transformation** | `k360:TransformationProgram, Initiative, AdoptionMetric, TransformationFatigue, BusinessOutcome` | transformation progress, adoption, change fatigue |
| 4 | **FinOps** | `k360:Budget, CostRecord, Forecast, CostAnomaly, CostOptimization, SpendCategory` | budget vs. spend, forecast, cost anomalies & optimization |
| 5 | **OKR** | `k360:OKR, Objective, KeyResult, AlignmentScore, OrphanedProject, OKRCascade` | strategy alignment, orphaned work, cascade integrity |
| 6 | **Governance** | `k360:Policy, PolicyRule, ComplianceCheckpoint, ComplianceViolation, AuditTrail, Risk` | policy-as-code, compliance checkpoints, violations, audit |
| 7 | **Planning** | `k360:CapacityPlan, CapacityForecast, Roadmap, ResourceAllocation, Scenario` | capacity, dependencies, roadmap scenarios |
| 8 | **OCM — Org Change Mgmt** | `k360:ReadinessAssessment, AdoptionBarrier, ChangeImpact, TrainingRecord, CommunicationPlan` (ADKAR scores) | change readiness, adoption barriers, training |
| 9 | **Notification Orchestrator** | `k360:Notification, Alert, NotificationRule, EscalationPath, AgentFinding` | dedupe, prioritize, route, escalate findings |

Plus **agent operations**: `k360:Agent, AgentState, AgentMemory, A2AConversation,
A2AMessage, Intervention, AgentSkill` — the runtime substrate (memory, A2A bus,
lifecycle, interventions).

## 2. Inference-driven detection (the "well-architected" payoff)

The ontology declares **derived classes** so agents *infer* problems instead of hand-coding
every check. Examples in `k360.ttl`:

- **`k360:OrphanedProject`** — a project with no linked `k360:Objective` (OKR agent).
- **`k360:CostAnomaly`** — spend pattern outside expected bounds (FinOps).
- **`k360:TransformationFatigue`** — too many concurrent changes on a population (TMO/OCM).
- **`LowReadinessInitiative`** — high change-impact + low adoption readiness (OCM).
- **`k360:ComplianceViolation`** — checkpoint failing a `PolicyRule` (Governance).

Detection by graph rule = deterministic and auditable. The LLM then turns each derived
instance into a ranked, explained, human-readable recommendation with a suggested action.

## 3. First-iteration agents (the vertical slice)

We ship **four** agents first. These map onto the chosen priorities and exercise the full
pipeline (ingest → graph → reason → write-back → inbox) end to end:

| Iteration-1 agent | Maps to domain(s) | First concrete behavior |
|---|---|---|
| **Portfolio Insights & Risk** | Strategic PMO + VRO | Flag epics/features with schedule variance, blocked dependencies, low delivery confidence; surface portfolio-level risk roll-up |
| **Methodology Mapper** | bridging axioms + agent-ops | Classify incoming work items (OpenProject types / external imports) onto the SAFe spine using `bridging.ttl` reconciliation rules; normalize everything to one model |
| **Flow & Delivery Optimizer** | Strategic PMO (FlowMetric) + Planning | Watch WIP / throughput / cycle time per ART; recommend flow improvements (WIP limits, bottleneck features) |
| **Planning & Dependency** | Planning + Strategic PMO | Detect cross-team dependencies & capacity conflicts ahead of PI planning; suggest sequencing |

The **Notification Orchestrator** is implicitly part of iteration 1 (every agent routes
findings through it for dedupe/prioritization before they hit the inbox), even though it
isn't a "headline" agent.

## 4. The common agent contract

Every agent — iteration-1 and beyond — implements the same lifecycle so the orchestrator
can schedule, monitor, and compose them:

```
observe(world: KGView)        → pull the relevant slice of the knowledge graph
  → reason()                  → run graph rules + LLM reasoning over that slice
  → emit(findings: Finding[]) → typed k360:AgentFinding/Intervention with
                                {sourceAgent, confidence, provenance, validFrom, links[]}
  → remember(memory)          → persist k360:AgentMemory; update k360:AgentState
```

Findings then flow to the **Notification Orchestrator** → dedupe/prioritize →
`modules/agentic_ppm` API → **Insights inbox** (and optional work-package annotation).

## 5. Agent-to-agent collaboration (A2A)

Agents are not siloed. Via `k360:A2AMessage` on the A2A bus they compose, e.g.:
- OKR agent finds an `OrphanedProject` → asks VRO "is there any benefit attached?" → if
  none, the joint finding is "unfunded, unaligned project — candidate to cut."
- FinOps flags a `CostAnomaly` on a project → Strategic PMO checks `ScheduleVariance` →
  combined "over budget *and* behind schedule" carries higher priority.

This composition is exactly the cross-domain reasoning the single connected graph enables
and that siloed tools cannot do.

## 6. Learning loop

- Each recommendation in the inbox is **Accept / Dismiss / Snooze**-able; the outcome is
  written back and stored as feedback.
- `k360:AgentMemory` + the temporal graph let agents notice *trends* (e.g. "variance is
  accelerating") and tune thresholds and confidence over time.
