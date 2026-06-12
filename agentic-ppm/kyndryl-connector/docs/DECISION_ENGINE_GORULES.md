# Decision engine (GoRules ZEN) — a decision-table option on top of simple thresholds

Scope: this doc extends [`RULES_ENGINE.md`](./RULES_ENGINE.md) with a second kind
of rule. The rules engine described there evaluates **single-metric threshold
rules** (`metric operator threshold`). This adds a **decision rule**: a GoRules
**JDM** (JSON Decision Model) — a decision table / decision graph with an
expression language — evaluated in-process by the **GoRules ZEN** engine. The
*decide* step is the only thing that changes; everything else in
`RULES_ENGINE.md` (event + sweep triggers, previous-value memory, cooldown/dedup,
the dual-UI fan-out, OpenProject as the system of record) is reused verbatim.

It complements [`ORCHESTRATION_AND_RULES.md`](./ORCHESTRATION_AND_RULES.md)
(event-driven over polling) and leans on the same grounding discipline as the
threshold path: a decision-rule breach is a **deterministic, fully-grounded
detection** — the JDM runs over real synced graph data with no LLM in the loop;
the LLM only explains the breach afterwards.

---

## 1. Why a decision engine on top of thresholds

A threshold rule answers exactly one question: *is this one metric over/under a
line?* That covers a lot — `percentageDone crossed_below 50`, `budget_variance
delta_gt 10000` — and when one line is enough, you should keep using the
threshold form (it is simpler, cheaper, and needs no JDM).

But real governance is often **multi-factor**. "An Epic is *at risk*" is rarely a
single cutoff; it is a judgement over several metrics at once:

> An Epic is **critical** if `percentageDone < 50` **AND** `daysToDue < 14`
> **AND** `budget_variance > 0`; it is a **warning** if **any one** of those is
> true; otherwise it is fine.

Expressing that as threshold rules means three or more separate rules that can't
see each other, can't agree on a combined severity, and each fire their own
alert. A **decision table** expresses the whole judgement in one authored
artifact, with one combined output. That is what the decision engine adds:

- **Decision tables** — rows of `input conditions → output`, evaluated top-down
  with a hit policy. The natural shape for banded/multi-factor logic.
- **Expression language** — conditions like `percentageDone < 50`,
  `daysToDue < 14 and budget_variance > 0`, `severity in ['critical','warning']`
  — far more than a single `operator threshold` comparison.
- **Visual authoring** — the GoRules **`@gorules/jdm-editor`** React component
  lets a non-developer author and edit the table visually, no code deploy.

Rule of thumb:

- **One metric, one line → threshold rule.** Don't reach for a JDM.
- **Several metrics, combined severity, or banded outputs → decision rule.**

---

## 2. Layering — only the "decide" step is new

```
                AUTHOR (in OpenProject — system of record for rules)
   ┌───────────────────────────────┬───────────────────────────────────────┐
   │  threshold form               │  visual JDM editor                     │
   │  metric · operator · threshold│  @gorules/jdm-editor (decision table / │
   │  (kind = 'threshold')         │  graph)  →  kind = 'decision' + jdm     │
   └───────────────┬───────────────┴───────────────────┬───────────────────┘
                   │                                    │
                   └────────────────┬───────────────────┘
                                    ▼
                 AgentRule row stored in OpenProject
              ( kind · …threshold fields… · jdm:JSON )
                                    │
                                    │ (1) runtime pulls GET /agentic_ppm/api/rules.json
                                    ▼
   ┌─────────────────────────────────────────────────────────────────────────┐
   │  agent-runtime (agentic-ppm/agent-runtime/src/rules/) — EVALUATOR         │
   │                                                                          │
   │  trigger: EVENT-DRIVEN (OpenProject webhook → changed entity)            │
   │           + periodic SAFETY SWEEP            ← unchanged from RULES_ENGINE│
   │                                                                          │
   │  build the entity context (graph props + computed metrics + meta)        │
   │                                                                          │
   │   ┌─────────────────────────┐        ┌──────────────────────────────┐   │
   │   │ kind='threshold'        │        │ kind='decision'  ← NEW        │   │
   │   │ value operator threshold│        │ ZEN: decision.evaluate(ctx)   │   │
   │   │ (+ prev-value memory)   │        │  → {breach,severity,…}        │   │
   │   └────────────┬────────────┘        └───────────────┬──────────────┘   │
   │                └───────────────┬───────────────────────┘                  │
   │                                ▼                                          │
   │                    breach?  → cooldown / dedup        ← unchanged         │
   │                            → previous-value memory    ← unchanged         │
   └────────────────────────────────┬─────────────────────────────────────────┘
                                     ▼
                    DUAL-UI FAN-OUT  (identical to RULES_ENGINE §1/§2)
   ┌──────────────────────────┐   ┌──────────────────────────────────────────┐
   │  Kyndral-365 UI          │   │  OpenProject native inbox                │
   │   ApprovalQueue (HITL)   │   │   Agent Alert WP + comment + banner      │
   │   RulesPanel (read)      │   │   POST /agentic_ppm/api/alerts.json      │
   └──────────────────────────┘   └──────────────────────────────────────────┘
```

The point of the diagram: **the harness is reused.** The event + sweep trigger,
the `RuleState` previous-value memory, the cooldown/dedup, and the
OpenProject + Kyndral alert fan-out are exactly as specified in
`RULES_ENGINE.md`. The runtime branches on `kind` only at the *decide* step: a
`threshold` rule runs the `operator/threshold` comparison; a `decision` rule
hands the entity context to the ZEN engine and reads back a breach. Both produce
the same finding + alert shape, so downstream nothing else changes.

---

## 3. Decision INPUT context and OUTPUT contract

### 3.1 INPUT — what a JDM can read

For a `decision` rule the runtime builds one **context object** from the entity
and passes it to `decision.evaluate(ctx)`. The context is the entity's graph
properties plus computed metrics plus a small meta block. A JDM references these
by name in its expressions (e.g. `percentageDone < 50 and daysToDue < 14`).

| Field | Source | Notes |
|---|---|---|
| *(all graph node props)* | FalkorDB node | every synced property on the entity is in scope (status, type, custom fields `cf_*`, …) |
| `percentageDone` | graph node | alias of the node's `percentDone`/`percentageDone` property (matches the threshold-path metric name) |
| `budget_variance` | computed | EVM cost variance (same formula the threshold path uses) |
| `overdue` | computed | boolean — past due date and not done |
| `daysToDue` | computed | signed days until the due date (negative = overdue) |
| `spentHours` | computed | logged hours on the entity |
| `estimatedHours` | computed | estimated hours on the entity |
| *project metrics* | computed | project-level rollups (e.g. project `budget_variance`, schedule slip) when the entity belongs to a project |
| `ontologyClass` | meta | canonical class, e.g. `safe:Epic` (same value as the rule's `ontology_class`) |
| `nodeId` | meta | the graph node id / entity id |
| `now` | meta | evaluation timestamp (ISO 8601) |

Metric → property resolution and the "skip the rule if a metric can't be
resolved on this node" discipline are identical to `RULES_ENGINE.md` §4.4 — a
decision rule is grounded the same way a threshold rule is.

### 3.2 OUTPUT — the contract the JDM must return

`decision.evaluate(ctx)` returns `{ result }`. The runtime reads `result` and
requires it to match this contract (a single object **or an array** of these):

```json
{
  "breach": true,
  "severity": "critical",
  "message": "Epic at risk: 42% done, 9 days to due, budget over.",
  "action_kind": "escalate",
  "metric": "at_risk",
  "value": 42
}
```

| Field | Type | Meaning |
|---|---|---|
| `breach` | `boolean` | **required.** `false` (or no row hit) → no breach, no fan-out. |
| `severity` | `"info" \| "warning" \| "critical"` | optional; the severity recorded on the finding/alert. |
| `message` | `string` | optional; human-readable breach summary (used in the OpenProject comment / finding title). |
| `action_kind` | `"alert" \| "recommend" \| "escalate"` | optional; advisory hint, same meaning as the threshold path. |
| `metric` | `string` | optional; a label for what tripped (e.g. `at_risk`), carried into `evidence[]`. |
| `value` | `number \| string` | optional; the salient value, carried into `evidence[]`. |

If `result` is an **array**, each element is treated as a candidate breach
(e.g. a multi-hit decision table can emit several findings); the runtime fans out
each one whose `breach` is true. A JDM that hits no row (empty `result`) is **not
a breach** — exactly like a `crossed_below` rule that didn't cross.

The breach then flows into the **same** cooldown/dedup, previous-value memory,
and dual-UI fan-out described in `RULES_ENGINE.md` §1, §2 and §6.

---

## 4. Two worked JDM examples

These are real GoRules JDM (JSON Decision Model) decision tables. They install
and run in-process under `@gorules/zen-engine@0.54.0` on Node 22 (prebuilt
binary, no separate service): `new ZenEngine()`, `engine.createDecision(jdm)`,
`await decision.evaluate(ctx) → { result }`.

### 4.1 Example (a) — the Epic `percentageDone` bands (single-input decision table)

The user's Epic example expressed as a decision table: `percentageDone` falls
into a band → severity. (A single-input band table is the simplest case where a
JDM is clearer than three separate threshold rules.)

```json
{
  "nodes": [
    {
      "id": "input",
      "type": "inputNode",
      "name": "Epic context",
      "position": { "x": 80, "y": 120 }
    },
    {
      "id": "table",
      "type": "decisionTableNode",
      "name": "percentageDone bands",
      "position": { "x": 360, "y": 120 },
      "content": {
        "hitPolicy": "first",
        "inputs": [
          { "id": "pct", "name": "Percent done", "field": "percentageDone" }
        ],
        "outputs": [
          { "id": "breach",   "name": "Breach",   "field": "breach" },
          { "id": "severity", "name": "Severity", "field": "severity" },
          { "id": "message",  "name": "Message",  "field": "message" }
        ],
        "rules": [
          {
            "_id": "r1",
            "pct": "< 25",
            "breach": "true",
            "severity": "\"critical\"",
            "message": "\"Epic critically behind: under 25% done\""
          },
          {
            "_id": "r2",
            "pct": "< 50",
            "breach": "true",
            "severity": "\"warning\"",
            "message": "\"Epic behind: under 50% done\""
          },
          {
            "_id": "r3",
            "pct": ">= 50",
            "breach": "false"
          }
        ]
      }
    },
    {
      "id": "output",
      "type": "outputNode",
      "name": "Decision",
      "position": { "x": 640, "y": 120 }
    }
  ],
  "edges": [
    { "id": "e1", "sourceId": "input", "targetId": "table" },
    { "id": "e2", "sourceId": "table", "targetId": "output" }
  ]
}
```

For context `{ "percentageDone": 47, "ontologyClass": "safe:Epic", "nodeId": "wp:48213" }`
the `first` hit policy lands on `r2`, so:

```json
{ "result": { "breach": true, "severity": "warning", "message": "Epic behind: under 50% done" } }
```

For `{ "percentageDone": 72 }` it lands on `r3` → `{ "result": { "breach": false } }`
→ no breach, no fan-out.

### 4.2 Example (b) — multi-factor "at risk" (the case thresholds can't express)

Three factors combined into one severity: **critical** if all three are true,
**warning** if any one is true. `hitPolicy: "first"` gives the AND row priority
over the OR row.

```json
{
  "nodes": [
    {
      "id": "input",
      "type": "inputNode",
      "name": "Epic context",
      "position": { "x": 80, "y": 120 }
    },
    {
      "id": "table",
      "type": "decisionTableNode",
      "name": "Epic at-risk",
      "position": { "x": 360, "y": 120 },
      "content": {
        "hitPolicy": "first",
        "inputs": [
          { "id": "pct",  "name": "Percent done",    "field": "percentageDone" },
          { "id": "days", "name": "Days to due",     "field": "daysToDue" },
          { "id": "bv",   "name": "Budget variance", "field": "budget_variance" }
        ],
        "outputs": [
          { "id": "breach",      "name": "Breach",      "field": "breach" },
          { "id": "severity",    "name": "Severity",    "field": "severity" },
          { "id": "message",     "name": "Message",     "field": "message" },
          { "id": "action_kind", "name": "Action",      "field": "action_kind" },
          { "id": "metric",      "name": "Metric",      "field": "metric" }
        ],
        "rules": [
          {
            "_id": "r1",
            "pct": "< 50",
            "days": "< 14",
            "bv": "> 0",
            "breach": "true",
            "severity": "\"critical\"",
            "message": "\"Epic at risk: behind schedule, near due, and over budget\"",
            "action_kind": "\"escalate\"",
            "metric": "\"at_risk\""
          },
          {
            "_id": "r2",
            "pct": "< 50",
            "days": "",
            "bv": "",
            "breach": "true",
            "severity": "\"warning\"",
            "message": "\"Epic at risk: behind on delivery\"",
            "action_kind": "\"alert\"",
            "metric": "\"at_risk\""
          },
          {
            "_id": "r3",
            "pct": "",
            "days": "< 14",
            "bv": "",
            "breach": "true",
            "severity": "\"warning\"",
            "message": "\"Epic at risk: due date close\"",
            "action_kind": "\"alert\"",
            "metric": "\"at_risk\""
          },
          {
            "_id": "r4",
            "pct": "",
            "days": "",
            "bv": "> 0",
            "breach": "true",
            "severity": "\"warning\"",
            "message": "\"Epic at risk: over budget\"",
            "action_kind": "\"alert\"",
            "metric": "\"at_risk\""
          },
          {
            "_id": "r5",
            "pct": "",
            "days": "",
            "bv": "",
            "breach": "false"
          }
        ]
      }
    },
    {
      "id": "output",
      "type": "outputNode",
      "name": "Decision",
      "position": { "x": 700, "y": 120 }
    }
  ],
  "edges": [
    { "id": "e1", "sourceId": "input", "targetId": "table" },
    { "id": "e2", "sourceId": "table", "targetId": "output" }
  ]
}
```

(An empty input cell means "don't care", so `r2`–`r4` are the single-factor OR
rows and `r1` is the all-three AND row; `r5` is the default no-breach row.)

For context `{ "percentageDone": 42, "daysToDue": 9, "budget_variance": 3500 }`
all three of `r1`'s conditions hold and `first` returns it:

```json
{
  "result": {
    "breach": true,
    "severity": "critical",
    "message": "Epic at risk: behind schedule, near due, and over budget",
    "action_kind": "escalate",
    "metric": "at_risk"
  }
}
```

For `{ "percentageDone": 42, "daysToDue": 40, "budget_variance": -1000 }` only
`pct < 50` holds → `first` returns `r2`:

```json
{ "result": { "breach": true, "severity": "warning", "message": "Epic at risk: behind on delivery", "action_kind": "alert", "metric": "at_risk" } }
```

For `{ "percentageDone": 80, "daysToDue": 40, "budget_variance": -1000 }` it
falls through to `r5` → `{ "result": { "breach": false } }`.

---

## 5. GoRules ZEN vs built-in operators vs Camunda DMN

Three engines could "decide" — pick by the shape of the logic, not by habit.

| Use case | Use |
|---|---|
| Single metric over/under a line (`percentageDone crossed_below 50`, `budget_variance delta_gt 10000`) | **built-in threshold operators** (`kind='threshold'`) — simplest, cheapest, no JDM |
| Multi-factor / banded / expression logic, combined severity, or a non-developer must author it visually | **GoRules ZEN** (`kind='decision'`, JDM authored in `@gorules/jdm-editor`) |
| BPMN-coupled governance already running on **Camunda DMN** (DMN tables wired into BPMN process flows) | **keep Camunda DMN** for that — but don't stand up a second DMN engine for agent-facing rules |

Honest guidance:

- The built-in operators are not obsolete. For a single cutoff they are strictly
  better than a JDM — fewer moving parts, and they already support the stateful
  operators (`crossed_*`, `delta_*`, `changed`) that need previous-value memory.
  Reach for a decision rule only when one line genuinely isn't enough.
- **ZEN is the lighter, embeddable, agent-facing core.** It runs in-process
  (prebuilt Rust binary, no service to operate), sub-millisecond, and its JDM is
  a single JSON artifact we can store on the `AgentRule` row. That makes it the
  right default for *agent* decision logic.
- **Camunda DMN earns its keep only where it's already load-bearing** — i.e.
  heavyweight BPMN governance where DMN decisions are embedded in process
  orchestration. Kyndral already runs Camunda DMN there; leave it. The
  consolidation guidance is simply: **don't run two engines for the same job.**
  If a decision is agent-facing and not BPMN-coupled, author it as a GoRules JDM,
  not a parallel DMN table. If it's part of a Camunda process flow, keep it in
  DMN. New agent rules go to ZEN.

---

## 6. Authoring UX plan

Rules stay **authored in OpenProject** (the system of record — see
`RULES_ENGINE.md` §5). Decision rules add a `kind='decision'` + a `jdm` JSON
field on the `AgentRule` row.

**Phase 1 — shippable now: paste JDM JSON.** The OpenProject rule form accepts a
`kind` selector and, for `kind='decision'`, a `jdm` JSON textarea. An author
pastes a JDM (e.g. exported from the GoRules editor or one of §4's examples).
The runtime stores it, pulls it in `rules.json`, and evaluates it via ZEN. No new
infrastructure — this works the day the runtime understands `kind`.

**Phase 2 — visual editor in Kyndral.** Embed the GoRules visual editor
(`@gorules/jdm-editor`) in the Kyndral UI via the **`DecisionEditor.tsx`** drop-in
(`client/src/openproject/DecisionEditor.tsx`). It binds `{ value: jdm, onChange,
onSave, readOnly? }` and renders the visual decision-table / graph editor, then
saves the JDM **back to OpenProject** (OpenProject stays the system of record;
Kyndral writes *into* it, mirroring the authoring-parity plan in `RULES_ENGINE.md`
§5/§7).

> **Small gap to close for Phase 2 write-back.** Kyndral's rules path is read-only
> today (`RulesPanel` via the `/api/agent/rules` proxy). To save a JDM back you
> need a **write endpoint** — either a new `PATCH /agentic_ppm/api/rules/:id`
> (accepting `{ kind, jdm }`) or the existing OpenProject rules CRUD — fronted by
> a Kyndral server proxy alongside the `/api/agent/*` routes (same pattern as the
> findings proxy, token held server-side). `DecisionEditor`'s `onSave` is the
> client half; this endpoint is the server half. Until it exists, `DecisionEditor`
> is usable in `readOnly`/local-state mode (author still pastes JSON in OpenProject
> for Phase 1).

---

## 7. Install / runtime notes

- **Server (agent-runtime):** `npm i @gorules/zen-engine`. Verified:
  `@gorules/zen-engine@0.54.0` installs and runs in-process on Node 22 (prebuilt
  binary, **no separate service**). It evaluated a JDM decision table against an
  Epic context and returned `{ breach, severity }`. API:
  `new ZenEngine()` → `engine.createDecision(jdmObject)` →
  `await decision.evaluate(ctx)` → `{ result }`.
- **Client (Kyndral):** `npm i @gorules/jdm-editor` (+ its CSS) — the visual JDM
  editor that `DecisionEditor.tsx` wraps.
- **Env:** `RULES_ZEN_ENABLED` gates the decision-engine path in the runtime
  (decision rules are skipped when off; threshold rules are unaffected).
- **Performance:** in-process Rust, **sub-millisecond** typical per evaluation —
  fast enough to run on the event path (per changed entity) and in the safety
  sweep without a measurable cost change versus the threshold path.

---

## 8. How this fits the existing contract (nothing else changes)

- **System of record:** OpenProject, unchanged. `kind` + `jdm` are new columns on
  `AgentRule`; threshold rules keep all their existing fields.
- **Trigger:** event-driven on the OpenProject webhook + periodic safety sweep —
  unchanged (`RULES_ENGINE.md` §3). Never a tight scan loop.
- **Memory / cooldown / dedup:** unchanged (`RULES_ENGINE.md` §6). A decision rule
  can still emit a `metric`/`value` so the previous-value and dedup machinery has
  something to key on.
- **Fan-out:** unchanged — a decision breach reaches **both UIs** (OpenProject
  Agent Alert WP + comment + banner + `alerts.json`, AND the Kyndral
  ApprovalQueue / RulesPanel), with the same finding `evidence[]` shape.
- **Grounding:** unchanged — the JDM runs over real computed/synced metrics, no
  LLM; the LLM only narrates the breach afterwards.

The only new thing in the whole pipeline is the *decide* step for
`kind='decision'`: ZEN evaluates the JDM. That is the entire surface area of this
extension.
