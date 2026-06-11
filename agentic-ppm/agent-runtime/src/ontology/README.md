# Ontology mapping layer

The runtime realization of the Smith Clarity ontology (`agentic-ppm/ontology/`).
FalkorDB has no OWL reasoner, so the ontology is **compiled** into code here:

- **`spine.ts`** — the canonical `pm:` spine (node labels, relationship types,
  property names). Every source maps onto this; queries speak only the spine.
- **`mapping.ts`** — the executable form of `bridging.ttl`:
  - `TYPE_MAPS` — native type → spine label + dialect class, per source
    (the "External System Aliases").
  - `applyReconciliation` — the conditional "Reconciliation Rules" (e.g. an agile
    Task with story points becomes a Story) that OWL can't express.
  - `FIELD_MAPS` / `mapFields` — native field names → canonical properties
    (the "Data Source Semantic Reconciliation": Jira `summary` = MSP `Name` = `name`).
  - `canonicalId` — stable cross-tool identity hook.

## Architecture

```
  source tool ──► adapter ──► mapType()/mapFields() ──► spine node (+ provenance)
```

Every node carries provenance (`source`, `ingestedVia`, `nativeType`, `nativeId`,
`dialectClass`, `canonicalId`) so a Jira epic and a Planview project that are the
same initiative can be reconciled instead of duplicated.

**OpenProject is the hub:** most data is ingested *into* OpenProject, so the
OpenProject adapter (`projector.ts`) is the workhorse. It reads each work
package's true origin from `customField_source_system` (default `openproject`)
and tags the graph node accordingly.

## Adding a new source (Jira / MS Project / Planview)

It's three config tables — no new mapping logic:

1. Add the native type map to `TYPE_MAPS` (most are already stubbed).
2. Add the field map to `FIELD_MAPS`.
3. Write a thin adapter that pulls records (e.g. via the tool's MCP server) and
   calls `mapType(source, nativeType, props)` + `mapFields(source, raw)`, then
   upserts spine nodes — mirroring what `projector.ts` does for OpenProject.

Keep `TYPE_MAPS`/`FIELD_MAPS` faithful to `bridging.ttl`; the ontology stays the
source of truth and this stays generated-from.
