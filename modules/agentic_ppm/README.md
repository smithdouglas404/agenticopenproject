# OpenProject Agentic PPM module

The native Rails engine for the Agentic PPM platform. It is the OpenProject-side
foundation that the TypeScript agent runtime and the FalkorDB/Graphiti knowledge
graph build on. See the design docs in [`agentic-ppm/docs`](../../agentic-ppm/docs)
— especially [03 — Ontology ⇄ OpenProject mapping](../../agentic-ppm/docs/03-openproject-mapping.md)
and [08 — Product & SaaS architecture](../../agentic-ppm/docs/08-product-and-saas-architecture.md).

## What this module provides (Phase 1 scaffold)

| Concern | Where |
|---|---|
| **SAFe configuration** (work-package types + WSJF/Epic/EVM custom fields) | `lib/open_project/agentic_ppm/safe_blueprint.rb` (declarative source) seeded by `app/services/agentic_ppm/seed_safe_configuration_service.rb` |
| **Ontology binding** (Smith Clarity IRI ⇄ OpenProject) | `lib/open_project/agentic_ppm/ontology.rb` |
| **Agent recommendation store** (the Insights inbox / HITL surface) | `app/models/agentic_ppm/agent_recommendation.rb` + `db/migrate` + `app/controllers/agentic_ppm/recommendations_controller.rb` |
| **Project module + permissions + menu** | `lib/open_project/agentic_ppm/engine.rb` |

### The blueprint is the single source of truth

`SafeBlueprint` defines the SAFe types and custom fields **once**. Both the
seeder (which creates them in OpenProject) and the ontology binding (which maps
them to/from Smith Clarity IRIs) read from it, so they never drift apart.

### The ontology binding

`OpenProject::AgenticPpm::Ontology` is the one place the OpenProject ⇄ ontology
translation lives, used in both directions:

```ruby
reg = OpenProject::AgenticPpm::Ontology.registry

# forward: OpenProject -> RDF projection
reg.target_for_class("safe:Feature")   # => WorkPackageTypeTarget["Feature"]
reg.target_for_property("safe:wsjfScore") # => CustomFieldTarget["wsjf_score"]

# reverse: agent finding -> OpenProject record
reg.resolve_subject("safe:Feature/123")
# => { iri: "safe:Feature", id: 123, target: WorkPackageTypeTarget["Feature"] }
```

## Installing

1. The module is wired into `Gemfile.modules`, so `bundle install` picks it up.
2. Run migrations: `bundle exec rails db:migrate`.
3. Seed the SAFe configuration (idempotent, non-destructive):
   ```ruby
   AgenticPpm::SeedSafeConfigurationService.new.call
   ```
4. Enable the **Agentic PPM** module per project (Project settings → Modules).

## Rules system

A native rules/thresholds layer lets a human declare conditions ("alert me when
an Epic's `percentageDone` drops below 40") that the **TypeScript agent runtime**
pulls and **evaluates** against the knowledge graph. The Rails module is the
*authoring* side only — it never evaluates anything. When the runtime detects a
breach it POSTs back, and the breach is persisted as an `AgentRecommendation`
(`finding_type: "rule_breach"`) so it surfaces in the native Insights inbox.

| Concern | Where |
|---|---|
| **Rule store / authoring model** | `app/models/agentic_ppm/agent_rule.rb` + `db/migrate/20260610000001_create_agentic_ppm_agent_rules.rb` |
| **CRUD UI** | `app/controllers/agentic_ppm/rules_controller.rb` + `app/views/agentic_ppm/rules/*` |
| **Runtime pull API** | `app/controllers/agentic_ppm/api/rules_controller.rb` |
| **Runtime breach ingestion API** | `app/controllers/agentic_ppm/api/alerts_controller.rb` |

A rule with a `nil` `project_id` is **global** and applies to every project;
otherwise it is scoped to its project.

### Permissions

Added to the `:agentic_ppm` project module:

- `view_agent_rules` (`agentic_ppm/rules#index`)
- `manage_agent_rules` (full CRUD)

Both depend on `view_work_packages`.

### API authentication

The runtime is a service, not a logged-in user. Both API controllers
authenticate it with a shared bearer token stored in the plugin setting
`rules_api_token` (`Setting.plugin_openproject_agentic_ppm["rules_api_token"]`),
presented via either header:

```
Authorization: Bearer <rules_api_token>
X-OP-Rules-Token: <rules_api_token>
```

If the token is absent/blank they **fall back** to standard OpenProject request
authentication (session or API key via the core `accept_key_auth` macro), so a
logged-in user can also reach them. CSRF is skipped and `application/json` is
treated as an API request, mirroring core `Webhooks::Incoming::HooksController`.

### `rules.json` contract (runtime pulls this)

```
GET /projects/:project_id/agentic_ppm/api/rules.json
```

Returns the **enabled** global rules plus the project's enabled rules:

```json
{
  "rules": [
    {
      "id": 12,
      "project_id": 7,
      "ontology_class": "safe:Epic",
      "metric": "percentageDone",
      "operator": "lt",
      "threshold": 40.0,
      "threshold2": null,
      "severity": "warning",
      "cooldown_minutes": 60,
      "action_kind": "alert",
      "notify_openproject": true,
      "notify_kyndral": true,
      "enabled": true
    }
  ]
}
```

`operator` is one of: `gt`, `gte`, `lt`, `lte`, `eq`, `ne`, `changed`,
`delta_gt`, `delta_lt`, `outside_range`, `crossed_above`, `crossed_below`.
`threshold2` is the upper bound for `outside_range` / delta comparisons.

Optionally the runtime can stamp evaluation progress:

```
PATCH /agentic_ppm/api/rules/:id/evaluated.json   -> 204 No Content
```

### Alerts contract (runtime POSTs a breach)

```
POST /agentic_ppm/api/alerts.json
Content-Type: application/json
```

```json
{
  "agent": "RulesAgent",
  "ontology_subject": "safe:Epic/123",
  "title": "Epic 123 percentageDone fell below 40%",
  "body": "Observed 32% against a threshold of 40%.",
  "severity": "warning",
  "confidence": 0.9,
  "rule_id": 12,
  "metric": "percentageDone",
  "observed_value": 32,
  "threshold": 40,
  "operator": "lt"
}
```

This creates an `AgentRecommendation` with `finding_type: "rule_breach"`. The
`ontology_subject` (e.g. `"safe:Epic/123"`) is resolved through
`OpenProject::AgenticPpm::Ontology` to attach the recommendation to the right
work package / project. `evidence` is stored as
`{ rule_id, metric, observed_value, threshold, operator }`. Response: `201` with
`{ "id": <recommendation_id> }`.

## Not yet in this scaffold

Default workflows, per-project templates, the RDF projector, the webhook
ingestion into the graph, and the polished cross-project front end are tracked
in [docs/06 — roadmap](../../agentic-ppm/docs/06-roadmap.md). This module
deliberately establishes only the data foundation the rest depends on.
