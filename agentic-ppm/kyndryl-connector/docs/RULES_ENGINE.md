# Rules engine — author in OpenProject, evaluate in the runtime, alert in both UIs

Scope: the threshold/rules engine that spans the **forked OpenProject** (native
rules authoring), the **agent-runtime** (the evaluator), and the **Kyndral-365**
UI (a read view + the existing ApprovalQueue inbox). This doc is the **source of
truth for the contract** the three pieces implement against.

It complements [`ORCHESTRATION_AND_RULES.md`](./ORCHESTRATION_AND_RULES.md) — that
doc argued for event-driven over a 15-second polling loop and gave the rules
engine a "keep it, it's a sensible hybrid" verdict. This doc is the next layer
down: it specifies *how* rules are authored, where they live, and exactly how a
breach fans out. It also leans on [`GROUNDING_AND_HALLUCINATION.md`](./GROUNDING_AND_HALLUCINATION.md):
rule breaches are **deterministic, fully-grounded detections** (Tier 2 "reactive
watcher" — no LLM, no hallucination risk); the LLM only explains them afterwards.

---

## 1. The big picture

```
   ┌─────────────────────────────────────────────────────────────────────┐
   │  OpenProject (forked, modernized)  —  SYSTEM OF RECORD FOR RULES      │
   │                                                                      │
   │  agentic_ppm module → Rules authoring UI                             │
   │    author/edit AgentRule rows (id, ontology_class, metric,           │
   │    operator, threshold, severity, notify_* , cooldown, action_kind)  │
   │                                                                      │
   │  GET  /agentic_ppm/api/rules.json   → { rules:[...] }   (pull)       │
   │  POST /agentic_ppm/api/alerts.json  ← breaches posted back (push)    │
   └──────────────┬───────────────────────────────────────▲──────────────┘
                  │ (1) pull rules                         │ (4b) post breach
                  │     RULES_REFRESH_MINUTES              │      to alerts.json
                  ▼                                        │
   ┌─────────────────────────────────────────────────────────────────────┐
   │  agent-runtime  (agentic-ppm/agent-runtime/src/rules/) — EVALUATOR    │
   │                                                                      │
   │  evaluates rules against the FalkorDB graph:                         │
   │    • EVENT-DRIVEN  → on OpenProject webhook change, evaluates ONLY    │
   │                       the entity that changed (≈ ms latency)          │
   │    • SAFETY SWEEP  → periodic full pass, catches anything missed      │
   │  remembers previous values (for delta/changed/crossed operators)     │
   │  respects cooldown_minutes / dedup                                   │
   │                                                                      │
   │  on breach (4):                                                      │
   │    (4a) record a finding  ──────────────┐                            │
   │    (4b) POST /agentic_ppm/api/alerts.json (back to OpenProject)      │
   └──────────────┬──────────────────────────┼───────────────────────────┘
                  │ (4a) findings            │ (4a) native OpenProject
                  ▼                          ▼
   ┌──────────────────────────┐   ┌──────────────────────────────────────┐
   │  Kyndral-365 UI          │   │  OpenProject native inbox            │
   │   • ApprovalQueue (HITL) │   │   • Agent Alert work package         │
   │     /api/agent/findings  │   │   • comment on the breached WP       │
   │     ?type=RuleBreach     │   │   • status banner on the project     │
   │   • RulesPanel (read)    │   │   • Insights / Rules inbox           │
   │     /api/agent/rules     │   │                                      │
   │  human triages in EITHER UI — both see the same breach              │
   └──────────────────────────┘   └──────────────────────────────────────┘
```

The single most important property: **a breach reaches BOTH UIs**. A human can
sit in OpenProject *or* in Kyndral-365 and see — and triage — the same event.

---

## 2. Worked examples (end-to-end)

### Example A — the user's scenario: a threshold on an Epic changes

The rule (authored in OpenProject, stored as an `AgentRule` row):

```json
{
  "ontology_class": "safe:Epic",
  "metric": "percentageDone",
  "operator": "crossed_below",
  "threshold": 50,
  "severity": "critical",
  "notify_openproject": true,
  "notify_kyndral": true,
  "action_kind": "escalate",
  "cooldown_minutes": 60
}
```

Flow:

1. A user edits the Epic — in **OpenProject** (drags `% done` from 54 → 47) **or
   in Kyndral-365** (which writes back to OpenProject via the connector). Either
   way the change lands in OpenProject.
2. OpenProject fires its **webhook** → the runtime receives the changed Epic.
3. The runtime evaluates **only that Epic** against rules whose
   `ontology_class` resolves to `safe:Epic`. It resolves `metric:percentageDone`
   to the graph property, reads the **previous** value it remembered (54) and
   the new value (47).
4. `crossed_below 50` is **true** (was ≥ 50, now < 50) → **breach**. Cooldown is
   checked (no breach for this rule+entity in the last 60 min) → proceed.
5. Fan-out:
   - **Finding** recorded (`type: "RuleBreach"`, `severity: "critical"`, evidence
     `[{entityId: <epic>, metric: "percentageDone", value: 47}]`).
   - **Kyndral**: the finding appears in `ApprovalQueue` and in the read-only
     `RulesPanel` "recent breaches" list (`/api/agent/findings?type=RuleBreach`).
   - **OpenProject**: an **Agent Alert** work package + a **comment** on the Epic
     + a **banner**; and the runtime **POSTs** the breach to
     `/agentic_ppm/api/alerts.json` so it shows in OpenProject's Insights/Rules
     inbox.
6. A human triages in **either** UI.

### Example B — `delta_gt` on budget variance

```json
{
  "ontology_class": "pm:Project",
  "metric": "budget_variance",
  "operator": "delta_gt",
  "threshold": 10000,
  "severity": "warning",
  "notify_openproject": true,
  "notify_kyndral": true,
  "action_kind": "alert"
}
```

`delta_gt 10000` fires when `budget_variance` **increased by more than 10,000
since the last observed value** (needs previous-value memory — see §4). A
re-baselined project whose variance jumps from 4,000 to 16,000 breaches; a slow
drift of 500 per sweep never does. This is why the operator compares the *delta*,
not the absolute value.

### Example C — `changed` on a custom field

```json
{
  "ontology_class": "pm:Task",
  "metric": "cf_go_no_go",
  "operator": "changed",
  "severity": "info",
  "notify_openproject": false,
  "notify_kyndral": true,
  "action_kind": "recommend"
}
```

`metric` here is an OpenProject **custom field key** (`cf_go_no_go`). `changed`
fires whenever the resolved value differs from the remembered previous value
(no `threshold` needed). With `notify_openproject:false`, this one only fans out
to Kyndral — useful for soft signals you don't want to clutter the OpenProject
inbox with.

---

## 3. Why event-driven, not constant polling

The instinct "constantly scan all ontology elements so a threshold change is
caught immediately" is the right *goal* but the wrong *mechanism*. We satisfy it
with **two paths, neither of which is a tight scan loop**:

1. **Event evaluation (the fast path).** On an OpenProject webhook, the runtime
   evaluates **only the entity that changed**, against only the rules whose
   `ontology_class` matches. Latency is ~milliseconds after the edit — *faster*
   than any poll interval, and it touches one entity, not the whole portfolio.
2. **Periodic safety sweep (the net).** A full pass on a slow cadence
   (`RULES_REFRESH_MINUTES`, default 15) re-evaluates everything to catch changes
   that arrived without a webhook (bulk imports, direct DB edits, missed
   deliveries) and to re-arm delta/crossed memory.

This is the same argument `ORCHESTRATION_AND_RULES.md` makes about orchestration:
a fixed 15-**second** loop that re-scans **unchanged** entities all day is the
smoking-gun cost (~$10–15k/yr, ~31.5M cycles/yr) and it makes the system feel
un-dynamic because it fires on a clock, not on what happened. Event-evaluation
plus a slow sweep is **~93% cheaper** and acts in ms instead of up to the loop
interval. The rule trigger **is** the event. Do not reintroduce a tight scan
loop for rules.

---

## 4. Data contracts

### 4.1 `GET /agentic_ppm/api/rules.json` → `{ rules: [...] }`

The runtime pulls this; Kyndral's `RulesPanel` reads a proxied copy at
`/api/agent/rules`. Exact shape:

```json
{
  "rules": [
    {
      "id": "rule_a1b2c3",
      "project_id": null,
      "name": "Epic delivery slipping below half-done",
      "description": "Escalate when a SAFe Epic crosses below 50% complete.",
      "ontology_class": "safe:Epic",
      "metric": "percentageDone",
      "operator": "crossed_below",
      "threshold": 50,
      "threshold2": null,
      "severity": "critical",
      "enabled": true,
      "notify_openproject": true,
      "notify_kyndral": true,
      "cooldown_minutes": 60,
      "action_kind": "escalate"
    }
  ]
}
```

Field notes:
- `project_id` — `null` means a **global** rule (applies to all projects);
  otherwise it scopes to one OpenProject project.
- `ontology_class` — canonical ontology class (e.g. `safe:Epic`, `pm:Task`,
  `pm:Project`); resolved through the runtime's `mapping.ts` spine so every
  source's types land on the same `pm:`/`safe:` classes.
- `metric` — a known metric key (`percentageDone`, `budget_variance`,
  `schedule_variance_days`, `risk_score`, …) **or** an OpenProject custom field
  key. Resolution to a graph property is in §4.4.
- `threshold` / `threshold2` — `threshold2` is used only by `outside_range`
  (the upper bound). For operators that don't need a value (`changed`),
  `threshold` may be `null`.
- `severity` — `info | warning | critical`.
- `notify_openproject` / `notify_kyndral` — independent fan-out toggles.
- `cooldown_minutes` — suppress re-firing the same rule+entity within the window.
- `action_kind` — `alert | recommend | escalate` (advisory hint for how the
  finding is presented/handled downstream).

### 4.2 `POST /agentic_ppm/api/alerts.json` (runtime → OpenProject)

When a rule breaches and `notify_openproject` is true, the runtime POSTs the
breach back so OpenProject can render it in its native inbox. Exact body:

```json
{
  "rule_id": "rule_a1b2c3",
  "ontology_class": "safe:Epic",
  "entity_id": "wp:48213",
  "project_id": 17,
  "work_package_id": 48213,
  "metric": "percentageDone",
  "operator": "crossed_below",
  "threshold": 50,
  "previous_value": 54,
  "current_value": 47,
  "severity": "critical",
  "action_kind": "escalate",
  "message": "Epic 'Payments Platform' crossed below 50% done (54 → 47).",
  "finding_id": "find_9z8y7x",
  "detected_at": "2026-06-12T14:03:21Z"
}
```

Notes:
- `previous_value` is `null` for stateless operators (`gt`, `lt`, `eq`, …) on a
  first observation.
- `finding_id` cross-links the OpenProject alert to the Kyndral finding so a
  triage in one UI can be reconciled with the other.
- The response is `2xx` on accept; the runtime treats non-2xx as retriable.

### 4.3 Operator semantics

| Operator | Fires when | Needs `threshold` | Needs `threshold2` | Needs **previous-value memory** |
|---|---|---|---|---|
| `gt` | value > threshold | yes | — | no |
| `gte` | value ≥ threshold | yes | — | no |
| `lt` | value < threshold | yes | — | no |
| `lte` | value ≤ threshold | yes | — | no |
| `eq` | value == threshold | yes | — | no |
| `ne` | value != threshold | yes | — | no |
| `changed` | value differs from previous | no | — | **yes** |
| `delta_gt` | (value − previous) > threshold | yes | — | **yes** |
| `delta_lt` | (value − previous) < threshold | yes | — | **yes** |
| `outside_range` | value < threshold **or** value > threshold2 | yes | yes | no |
| `crossed_above` | previous ≤ threshold **and** value > threshold | yes | — | **yes** |
| `crossed_below` | previous ≥ threshold **and** value < threshold | yes | — | **yes** |

The operators marked **yes** under previous-value memory need the runtime to
remember the last observed value per (rule, entity). On a first observation with
no remembered value, the runtime records the value and **does not breach** (it
arms the comparison for next time) — so `crossed_*`/`changed`/`delta_*` never
false-fire on the initial read.

### 4.4 metric → graph-property resolution

The runtime resolves `metric` to a value on the FalkorDB graph node:
- **Known metrics** map to computed/synced node properties:
  `percentageDone` → node `percentDone`/`percentageDone`;
  `budget_variance` → computed EVM variance; `schedule_variance_days` → computed
  schedule slip in days; `risk_score` → computed P×I risk score.
- **Custom fields** (`cf_*` / OpenProject custom field key) map to the synced
  custom-field property on the node. If a metric can't be resolved on a given
  node, that rule is **skipped** for that node (it is not a breach and not an
  error) — consistent with the entity-existence / grounding discipline in
  `GROUNDING_AND_HALLUCINATION.md` §2.

Because metrics are **computed deterministically** (not LLM-generated), a rule
breach is fully grounded: the threshold math runs on real synced data, and the
finding carries `evidence:[{entityId, metric, value}]`.

---

## 5. Where rules live, and why in OpenProject

Rules are authored **natively in the forked OpenProject** (`modules/agentic_ppm`)
and stored as `AgentRule` rows. **OpenProject is the system of record for rules.**
Reasons:

- **The fork is to modernize.** OpenProject was forked specifically so we can add
  native capability without the community-upgrade constraint. Authoring rules in
  the module is exactly the kind of AI-modernization the fork exists for, and it
  seeds an AI-modernized open-source OpenProject.
- **Thresholds live with the work.** A rule about an Epic's `% done` belongs next
  to the Epic, in the same tool a PM already uses — not in a separate config file
  in another service. Authoring-in-place is lower-friction and auditable.
- **One source, two consumers.** The runtime pulls rules; Kyndral reads them. Both
  read from the same `rules.json`, so there's no drift.

**Kyndral can also author rules later** via the same API (POST/PATCH against the
OpenProject rules endpoints) if we want authoring parity in the Kyndral UI — but
even then OpenProject remains the **system of record**; Kyndral would be writing
*into* it, not keeping its own copy. For now the Kyndral side is **read-only**
(see `RulesPanel.tsx`): it lists active rules and recent breaches, with a clear
"Authored in OpenProject" note and a deep link.

---

## 6. Permissions / auth, env vars, cooldown & dedup

### Auth
- `GET /agentic_ppm/api/rules.json` and `POST /agentic_ppm/api/alerts.json`
  require **both**:
  - `X-OP-Rules-Token` header (a shared secret for the rules channel), **and**
  - OpenProject **apikey basic auth** (`apikey:<key>`), the same credential the
    connector already uses.
- The Kyndral browser never sees either secret: `RulesPanel` calls
  `/api/agent/rules`, a **server proxy** (mirroring
  `server/routes/agentFindings.routes.ts`) that holds the token server-side and
  forwards to `rules.json`. This proxy path does not exist yet — it must be added
  alongside the existing `/api/agent/*` routes.

### Env vars (runtime side)
| Var | Meaning |
|---|---|
| `RULES_ENABLED` | master on/off for the rules engine |
| `RULES_SOURCE` | where rules come from (e.g. `openproject` — the rules.json endpoint) |
| `RULES_API_TOKEN` | the `X-OP-Rules-Token` value |
| `RULES_REFRESH_MINUTES` | rule-pull cadence **and** the safety-sweep interval (default 15) |

### Cooldown & dedup
- **Cooldown**: after a rule breaches for a given entity, the same (rule, entity)
  is suppressed for `cooldown_minutes`. This prevents a flapping metric from
  spamming both inboxes.
- **Dedup**: an already-open RuleBreach finding for the same (rule, entity) is
  not duplicated — the existing finding is updated (new current value /
  timestamp) rather than a second one raised.
- **Memory**: previous values for `delta_*`/`changed`/`crossed_*` are remembered
  per (rule, entity) across both the event path and the sweep, so the two paths
  agree on "what was the last value".

---

## 7. Phased rollout

**Phase 1 — shippable now**
- `AgentRule` model + native authoring UI in `modules/agentic_ppm`.
- `rules.json` (pull) + `alerts.json` (push-back) endpoints with token + apikey
  auth.
- Runtime evaluation: event-driven on webhook + periodic safety sweep,
  previous-value memory, cooldown/dedup.
- Dual alerts: finding (→ Kyndral ApprovalQueue + RulesPanel) AND OpenProject
  Agent Alert WP + comment + banner + alerts.json post.
- Kyndral read-only `RulesPanel` (this connector).

**Phase 2 — richer**
- OpenProject UI: rule **templates**, **simulation / dry-run** ("how many of the
  last 30 days would this have fired?"), a per-Epic **Rules tab**.
- Kyndral **authoring parity** (write rules via the OpenProject API, OpenProject
  still the system of record).
- **ML-suggested thresholds** from the learning loop
  (`GROUNDING_AND_HALLUCINATION.md` §3): once outcome-tracking is wired, suggest
  thresholds that historically separated good/bad outcomes, and weight rule
  severity by which rules' breaches proved actionable.
