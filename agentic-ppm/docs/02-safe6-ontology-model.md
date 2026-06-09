# 02 — SAFe 6.0 as the Well-Architected Reference Model

This document explains how **SAFe 6.0** functions as the canonical reference model in the
Smith Clarity ontology, and how **other methodologies are mapped onto it**. All class and
property names below are the actual IRIs in `agentic-ppm/ontology/`.

## 1. The two-layer idea: a neutral spine + framework dialects

The ontology deliberately does **not** force one methodology. It defines:

- a **framework-neutral spine** in the `pm:` namespace
  (`http://nextera.energy/ontology/pm#`) — `Portfolio, Program, Project, Epic, Feature,
  Story, Task, Deliverable, Team, Resource, Risk, Milestone, Dependency, …`; and
- **dialects** that express each methodology as subclasses/equivalences of the spine:
  - `safe:` — SAFe 6.0 (the reference dialect)
  - `pmbok:` — PMBOK process/knowledge areas + Earned Value
  - `prince2:` — controlled stages, products, business case

```
                         pm:Portfolio                (neutral spine)
            ┌─────────────────┼──────────────────┐
   safe:Portfolio      pmbok:Portfolio     prince2:Programme
   (equivalentClass)   (subClassOf)        (subClassOf)
```

Because every dialect maps back to `pm:`, a reasoner sees a SAFe `Feature`, a PMBOK
`WorkPackage`, and a PRINCE2 `Product` as work on the *same* spine. That is what lets one
portfolio run even when business units use different methods.

## 2. The SAFe 6.0 hierarchy (the reference structure)

From `modules/safe.ttl` (+ the K360 refinement in `modules/k360.ttl`):

```
safe:Portfolio
  └─ safe:StrategicTheme            (connects portfolio to enterprise strategy)
  └─ safe:ValueStream   (⊑ pm:Program)
       └─ safe:ART      (Agile Release Train, ⊑ pm:Team)
            └─ safe:Team
            └─ safe:ProgramIncrement (PI, timebox)
                 └─ safe:Sprint     (iteration)
  Backlog of work items (safe:WorkItem):
       safe:Epic        (⊑ pm:Epic)        — large initiative, has Lean Business Case, MVP
         └─ safe:Capability (⊑ pm:Feature) — spans multiple ARTs
              └─ safe:Feature  (⊑ pm:Feature) — delivered by one ART in one PI
                   └─ safe:Story (⊑ pm:Story / ⊑ pm:Task)
       safe:Enabler     (⊑ pm:Task)        — architectural runway / exploration
```

### SAFe-specific properties that matter to agents
- **WSJF prioritization:** `safe:wsjfScore`, with inputs `safe:businessValue`,
  `safe:timeCriticality`, `safe:riskReduction` (RR/OE), `safe:jobSize`.
  `WSJF = (businessValue + timeCriticality + riskReduction) / jobSize`.
- **Epic governance:** `safe:epicType` (business|enabler), `safe:leanBusinessCase`,
  `safe:mvpStatement`, `safe:hypothesisStatement`.
- **Flow / cadence:** `safe:piObjectives`, `safe:plannedVelocity`, `safe:actualVelocity`,
  `safe:velocityTarget`, `safe:targetPI`.
- **Quality / architecture:** `safe:acceptanceCriteria`, `safe:nfrRequirement`,
  `safe:architecturalRunway`.

These are the levers the Flow, Planning, and Portfolio agents read and reason over.

## 3. Mapping other methodologies onto SAFe / the spine

The bridging axioms (`modules/bridging.ttl`) are the heart of "map other methodologies to
the well-architected model." Selected equivalences:

| Concept | SAFe | PMBOK | PRINCE2 | Neutral spine |
|---|---|---|---|---|
| Top of portfolio | `safe:Portfolio` | `pmbok:Portfolio` | Programme | `pm:Portfolio` |
| Mid coordination | `safe:ValueStream` | `pmbok:Program` | `prince2:Project` | `pm:Program` |
| Large initiative | `safe:Epic` | `pmbok:Project` | `prince2:Stage` | `pm:Epic`/`pm:Project` |
| Deliverable unit | `safe:Feature`/`Capability` | `pmbok:WorkPackage` | `prince2:Product` | `pm:Feature`/`pm:Deliverable` |
| Actionable work | `safe:Story` | `pmbok:Activity` | `prince2:Activity` | `pm:Task` |
| Delivery org | `safe:ART` | `pmbok` Team | PRINCE2 org structure | `pm:Team` |
| Timebox | `safe:PI` / `safe:Sprint` | Project Phase | Management Stage | `pm:Schedule` |

Encoded as e.g. `safe:Epic owl:equivalentClass pm:Epic`,
`pmbok:WorkPackage rdfs:subClassOf pm:Task`,
`prince2:Product owl:equivalentClass pm:Deliverable`.

### External tool aliases
The bridging module also pins down PPM-tool vocabularies so ingested data normalizes:
Jira/Azure DevOps/ServiceNow/Excel "Epic / Story / Task / Issue / assignee / status /
title / due date" all resolve to spine properties (`pm:isAssignedTo`, `pm:taskStatus`,
`pm:taskName`, `pm:hasDueDate`). **OpenProject is added to this list** in
`03-openproject-mapping.md`.

### Reconciliation rules (how ambiguous items get classified)
`bridging.ttl` encodes heuristics the **Methodology Mapper agent** operationalizes, e.g.:
- *Task with story points, from an agile context* → `safe:Story`
- *Project with a formal business case* → `prince2:Project`
- *Project with EVM metrics* → `pmbok:Project`
- *Default* → the most general spine class

**Mapping rule of thumb:** map to the *most specific* class you can justify; `subClassOf*`
makes it visible to every higher-level (SAFe/portfolio) query automatically.

## 4. Why SAFe is the "well-architected" choice

- It already spans **strategy → funding → delivery → flow** (Lean Portfolio Management,
  Value Streams, ARTs, PIs), so the spine has a natural home for every PPM concern.
- It carries **prioritization (WSJF)** and **flow** semantics that the agents need to
  reason about value and throughput — concepts PMBOK/PRINCE2 don't model natively.
- Its hierarchy is granular enough to absorb the others as special cases, but not so rigid
  that a waterfall PMBOK project can't be expressed against it.

## 5. The K360 refinement

`modules/k360.ttl` re-roots the SAFe classes under a **temporal, auditable** base
(`k360:Entity → TemporalEntity → AuditableEntity`) so every SAFe entity gains
`valid_from`/`valid_to`, `version`, and audit fields. This is what upgrades the model from
a static taxonomy to a **temporal knowledge graph** the agents can reason about *over
time*. The agent-domain classes layered on top are covered in `04-agent-roster.md`.

## 6. Practical implication for this project

The SAFe hierarchy in §2 is exactly what `modules/agentic_ppm` materializes inside
OpenProject as **work-package types + custom fields + project structure**, and exactly
what the projector emits as triples. SAFe is therefore the shared shape across all three
layers: OpenProject schema ⇄ ontology ⇄ agent reasoning.
