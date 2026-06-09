# Smith Clarity — Enterprise PPM Ontology

A formal, machine-readable model of how an enterprise actually runs project & portfolio
management (PPM). It is written in **W3C OWL / Turtle (`.ttl`)**, the same standard used
by Palantir Foundry, Protégé, GraphDB, Stardog, and every major knowledge-graph tool — so
it loads anywhere without translation.

This package contains the **modular source** (six files you can read one domain at a time)
and a single **merged "mega" ontology** (everything unified into one file for sharing,
import, or reasoning).

---

## 1. What's in the box

```
ontology-package/
├── smith-clarity-mega-ontology.ttl   ← ONE unified file (143 classes, ~1,870 triples)
├── modules/                          ← the original modular sources
│   ├── core.ttl                      pm:      framework-neutral PM concepts
│   ├── safe.ttl                      safe:    SAFe 6.0 hierarchy
│   ├── pmbok.ttl                     pmbok:   PMBOK process/knowledge areas
│   ├── prince2.ttl                   prince2: PRINCE2 controlled stages
│   ├── k360.ttl                      k360:    enterprise + 9 agent domains + temporal KG
│   └── bridging.ttl                  cross-framework equivalence axioms
└── README.md                         (this file)
```

### Coverage at a glance

| Module | Namespace | Classes | Obj. props | Data props | What it models |
|---|---|---:|---:|---:|---|
| Core | `pm:` | 18 | 17 | 28 | The neutral "spine": Portfolio, Program, Project, Epic, Feature, Story, Task, Deliverable, Team, Resource, Risk, Milestone |
| SAFe 6.0 | `safe:` | 12 | 9 | 17 | Portfolio → Value Stream → ART → PI → Team → Epic → Feature → Story → Enabler |
| PMBOK | `pmbok:` | 15 | 5 | 21 | Process groups & knowledge areas (scope, cost, schedule, risk, quality…) |
| PRINCE2 | `prince2:` | 14 | 5 | 25 | Stages, products, business case, controlled governance |
| K360 enterprise | `k360:` | 84 | 72 | 69 | 9 agent domains, temporal knowledge-graph properties, inference rules |
| Bridging | — | — | — | — | Equivalence axioms tying SAFe/PMBOK/PRINCE2 back to the `pm:` spine |
| **Mega (merged)** | all | **143** | **108** | **160** | All of the above + 9 auto-generated SAFe-unification bridges |

---

## 2. How the ontology is structured

### 2.1 A neutral spine, three framework dialects
Most PPM tools force you into one methodology. This ontology instead defines a
**framework-neutral core (`pm:`)** and then expresses SAFe, PMBOK, and PRINCE2 as
*dialects* that map onto that spine via `rdfs:subClassOf` and `owl:equivalentClass`.

```
                         pm:Portfolio
            ┌─────────────────┼──────────────────┐
   safe:Portfolio      pmbok:Portfolio     prince2:Programme
   (equivalentClass)   (subClassOf)        (subClassOf)
```

That means a SAFe `Feature`, a PMBOK `WorkPackage`, and a PRINCE2 `Product` are all
understood by a reasoner as deliverables on the same spine — you can run one portfolio
even if different business units use different methodologies.

### 2.2 Nine autonomous agent domains (K360)
The `k360.ttl` module is the largest because it models not just *work* but the
*management of work* by the 11-agent system:

| Agent domain | Representative classes |
|---|---|
| VRO (Value Realization) | `Benefit`, `BenefitRealization`, `ValueMetric`, `BusinessOutcome` |
| Strategic PMO | `DeliveryRisk`, `ScheduleVariance`, `DependencyAnalysis` |
| TMO (Transformation) | `TransformationProgram`, `Initiative`, `Scenario` |
| FinOps | `CostRecord`, `CostAnomaly`, `CostOptimization`, `Budget` |
| OKR | `Objective`, `KeyResult`, `OKRCascade`, `AlignmentScore` |
| Governance | `ComplianceCheckpoint`, `ComplianceViolation`, `Policy`, `PolicyRule` |
| Planning | `CapacityPlan`, `CapacityForecast`, `Roadmap`, `ResourceAllocation` |
| OCM (Change Mgmt) | `ReadinessAssessment`, `AdoptionBarrier`, `TransformationFatigue` |
| Notification | `Notification`, `NotificationRule`, `EscalationPath`, `Alert` |
| Agent operations | `Agent`, `AgentState`, `AgentFinding`, `AgentMemory`, `A2AMessage` |

### 2.3 Temporal knowledge-graph properties
Every K360 entity inherits `Entity → TemporalEntity → AuditableEntity`, giving it
`valid_from` / `valid_to` / versioning and a full audit trail. This is what lets the
agents reason about *change over time* ("budget variance is accelerating") rather than
just current state.

### 2.4 Inference rules & axioms
Sections 15–16 of the K360 module declare constraints and reasoning rules (e.g. an
`OrphanedProject` is a project with no linked objective; a `LowReadinessInitiative`
combines high change-impact with low adoption readiness). These let a reasoner *derive*
risk classes instead of you hand-flagging them.

---

## 3. How to map your data to it

There are three practical mapping paths depending on where your data lives.

### Path A — Palantir Foundry (the live source of truth here)
The running platform already maps **~20 `Atlas*` object types** onto this ontology.
The correspondence is:

| Ontology class | Palantir object type | Notes |
|---|---|---|
| `pm:Project` / `safe:Epic` | `AtlasProject` | milestones & resources embedded as `milestonesJson` / `resourcesJson` |
| `pm:Portfolio` | `AtlasPortfolio` | |
| `pm:Program` | `AtlasProgram` | |
| `safe:Feature` | `AtlasFeature` | |
| `safe:Story` | `AtlasStory` | |
| `pm:Task` | `AtlasTask` | |
| `pm:Milestone` | `AtlasMilestone` | |
| `pm:Risk` | `AtlasRisk` | |
| `pm:Dependency` | `AtlasDependency` | |
| `pm:Resource` | `AtlasResource` | |
| `pm:Team` | `AtlasTeam` | |
| `k360:Objective` | `AtlasObjective` | |
| `k360:KeyResult` | `AtlasKeyResult` | |
| `k360:ComplianceCheckpoint` | `AtlasGovernanceCheckpoint` | |
| `k360:Agent` | `AtlasAgent` | |

To extend: create a Foundry object type, then add `rdfs:label` / property names that match
the ontology's class and datatype-property local names. Foundry's ontology importer accepts
OWL directly, so you can also load `smith-clarity-mega-ontology.ttl` and align by IRI.

### Path B — A relational / CSV source
1. Pick the ontology class each table maps to (e.g. `projects` → `pm:Project`).
2. Map each column to a datatype property (`budget` → `pm:hasBudget`, `status` →
   `pm:status`). The property names and expected `xsd:` datatypes are declared in the file.
3. Map foreign keys to object properties (`project.portfolio_id` → `pm:belongsToPortfolio`).
4. Emit one RDF triple per cell, or use a tool like **R2RML** / **Ontop** to expose the
   database as a virtual graph without copying data.

### Path C — Another methodology
If your organisation is "pure PMBOK" or "pure PRINCE2", map to that dialect module and let
the **bridging axioms** project you onto the neutral spine automatically. You get
cross-framework portfolio roll-ups for free.

> **Mapping rule of thumb:** map to the *most specific* class you can justify, then rely on
> `rdfs:subClassOf` to make it visible to every higher-level query. Mapping a record to
> `safe:Feature` automatically makes it a `pm:Feature` and a `pm:WorkItem` to any reasoner.

---

## 4. Why this matters in the PPM process

A shared ontology is the difference between *reports* and *reasoning*. Concretely:

1. **One language across methodologies.** Finance speaks cost centres, delivery speaks
   SAFe, the PMO speaks PMBOK. The neutral `pm:` spine lets all three roll up into one
   portfolio view without a manual reconciliation spreadsheet.

2. **Cross-domain questions become answerable.** Because risk, budget, schedule, OKRs and
   change-readiness all live in *one* connected graph, you can ask "which strategic
   objectives are funded by over-budget projects that also have low adoption readiness?" —
   a query that is impossible when each domain sits in its own tool.

3. **Agents can act, not just display.** The 11 autonomous agents read this ontology as
   their world model. `k360:AgentFinding`, `k360:Intervention`, and the inference rules let
   an agent *derive* "this is an orphaned project" and raise a typed, auditable
   recommendation — instead of a human eyeballing a dashboard.

4. **Governance & audit are built in.** Temporal properties + `AuditTrail` mean every value
   has a history and provenance. When a regulator asks "who changed this budget and when",
   the answer is in the graph, not in someone's inbox.

5. **Early-warning instead of post-mortem.** Inference classes like
   `TransformationFatigue`, `CostAnomaly`, and `LowReadinessInitiative` turn lagging status
   reports into leading indicators the system can flag before a project derails.

6. **Vendor-neutral & future-proof.** Being standard OWL, the model outlives any single
   tool. Swap Jira for Azure DevOps, or Foundry for another graph store — the meaning of
   your portfolio data stays intact.

In short: it upgrades PPM from *"a place where status is recorded"* to *"a system that
understands the portfolio well enough to reason about it."*

---

## 5. Quick start

**Open & explore visually:** load `smith-clarity-mega-ontology.ttl` into
[Protégé](https://protege.stanford.edu/) → the class hierarchy, properties, and axioms are
all browsable.

**Validate / count triples (Node):**
```bash
npm i n3
node -e "const N3=require('n3'),fs=require('fs');let c=0;new N3.Parser().parse(fs.readFileSync('smith-clarity-mega-ontology.ttl','utf8'),(e,q)=>{if(e)throw e;q?c++:console.log('triples:',c)})"
```

**Load into a triple store:** GraphDB, Stardog, Apache Jena Fuseki, or Blazegraph all
import the `.ttl` directly; then query with SPARQL.

**Import into Palantir Foundry:** use the Ontology importer and align by class/property IRI.

---

*Generated from the Smith Clarity ontology modules. The mega file is regenerated from the
six modules via `scripts/build-mega-ontology.cjs`, which unifies prefixes and auto-creates
equivalence bridges between the two SAFe namespaces.*
