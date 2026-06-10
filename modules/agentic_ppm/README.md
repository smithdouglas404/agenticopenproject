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

## Not yet in this scaffold

Default workflows, per-project templates, the RDF projector, the webhook
ingestion into the graph, and the polished cross-project front end are tracked
in [docs/06 — roadmap](../../agentic-ppm/docs/06-roadmap.md). This module
deliberately establishes only the data foundation the rest depends on.
