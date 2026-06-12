# Palantir → FalkorDB migration plan (ontology backend swap)

Scope: Kyndral-365 DOSv2. The UI reads ontology objects (Project, Feature,
Story, Task, Risk, …) through `/api/palantir/ontology/*` routes backed by
`OntologyDataProvider`, which persists to Postgres + **Palantir Foundry**. This
plan swaps the backend to **FalkorDB** using
`server/FalkorOntologyDataProvider.ts` (in this connector). **The URLs and the
UI do not change — only the provider behind the routes swaps.**

## Why FalkorDB

- **One already-deployed service.** The agent-runtime in this repo already runs
  FalkorDB in production for the OpenProject world-model — no new infra, no new
  vendor onboarding.
- **openCypher.** Same query language family the graph layer already speaks
  (DOSv2's Neo4j `schema.cypher` shapes port over directly); MERGE-by-id
  upserts, relationship traversal, aggregations all map 1:1.
- **Vector index for GraphRAG.** FalkorDB has native vector indexing, so
  `searchObjects` can graduate from CONTAINS to embedding search and agents get
  GraphRAG over the live ontology — something the Foundry round-trip never gave us.
- **No Foundry licensing/latency.** Removes the Palantir license cost and the
  external round-trip + credential surface; the graph lives next to the app.

## Proof the pattern works (this repo)

The agent-runtime already proves the exact loop on FalkorDB:

- `agent-runtime/src/graph/falkor.ts` — the connection/query/sanitize pattern
  `FalkorOntologyDataProvider` mirrors (singleton, MERGE upserts, error-handler
  reconnect, label sanitizing, undefined-param cleaning).
- `agent-runtime/src/projector/` — OpenProject → graph projection (the same job
  as ontology object upserts).
- `agent-runtime/src/detectors/` — rule/inference detectors querying that graph
  to raise findings — i.e. agents reading the ontology from FalkorDB in prod.

## Method-by-method mapping

| OntologyDataProvider (Palantir) | FalkorOntologyDataProvider | Notes |
|---|---|---|
| `getObjects(type)` | `getObjects(objectType, filter?, limit?)` | label scan + optional exact-match filter |
| `getObject(type, id)` | `getObject(objectType, id)` | `MATCH (n:Type {id}) ` |
| `upsertObject(type, obj)` | `upsertObject(objectType, obj)` | `MERGE` by id, `SET n +=` (idempotent) |
| *(delete path)* | `deleteObject(objectType, id)` | `DETACH DELETE` |
| `linkObjects(fromT, fromId, rel, toT, toId)` | `linkObjects(..., props?)` | `MERGE` both ends + relationship |
| *(link reads)* | `getLinkedObjects(type, id, rel, direction)` | out / in / both |
| *(Foundry search)* | `searchObjects(type, text)` | CONTAINS over name/description; upgrade to vector index |
| *(Foundry SQL/dataset)* | `query(cypher, params)` | raw openCypher escape hatch |
| *(Foundry aggregations)* | `aggregate(type, groupBy, {op, property?})` | count / sum / avg group-by |
| *(auth/health)* | `health()` | connectivity probe for /health |

Labels = object types (`Project`, `Feature`, `Story`, `Task`, `Risk`);
relationship types = link types (`HAS_FEATURE`, `HAS_STORY`, `HAS_TASK`,
`HAS_RISK`, `ALIGNS_TO_OKR`, `DEPENDS_ON`, …). Both are sanitized against
`/^[A-Za-z_][A-Za-z0-9_]*$/` before interpolation.

## Env vars

| Var | Default | Meaning |
|---|---|---|
| `FALKORDB_HOST` | `localhost` | FalkorDB host |
| `FALKORDB_PORT` | `6379` | FalkorDB port (Redis protocol) |
| `FALKORDB_GRAPH` | `kyndral_ontology` | graph name |
| `FALKORDB_PASSWORD` | *(none)* | auth, if set |

Dependency: `npm i falkordb` (same client the agent-runtime uses).

### Railway note (IPv6)

Railway's private network is IPv6-first; Node may resolve the FalkorDB service
hostname to an unreachable A record. When any `RAILWAY_*` env var is present,
prefer IPv6 early in server startup:

```ts
import dns from "node:dns";
if (Object.keys(process.env).some((k) => k.startsWith("RAILWAY_"))) {
  dns.setDefaultResultOrder("ipv6first");
}
```

## The route change (the entire blast radius)

In the file that registers `/api/palantir/ontology/*` routes, replace the
provider construction:

```ts
// before
// const provider = new OntologyDataProvider(...palantir/foundry config...);

// after
import { getOntologyProvider } from "../FalkorOntologyDataProvider";
const provider = getOntologyProvider();
```

Route paths, request/response shapes, and every UI page stay identical —
**zero UI change**. (Optionally alias the routes to `/api/ontology/*` later;
keep `/api/palantir/ontology/*` serving until the frontend constant is updated.)

## Data migration (Postgres → FalkorDB)

The ontology objects already persist to Postgres, so the migration is an
export→upsert loop — no Foundry export needed:

1. Provision FalkorDB (or reuse the agent-runtime instance with a separate
   `FALKORDB_GRAPH`), set the env vars.
2. One-off backfill script (run with the server's storage layer):
   ```ts
   const provider = getOntologyProvider();
   for (const type of ["Project", "Feature", "Story", "Task", "Risk"] as const) {
     const rows = await storage[`get${type}s`]();        // existing Drizzle getters
     for (const row of rows) {
       await provider.upsertObject(type, { ...row, id: String(row.id) });
     }
   }
   // Links from the FKs:
   //   Feature.projectId → linkObjects("Project", projectId, "HAS_FEATURE", "Feature", id)
   //   Story.featureId   → linkObjects("Feature", featureId, "HAS_STORY",  "Story",  id)
   //   Task.storyId      → linkObjects("Story",  storyId,   "HAS_TASK",   "Task",   id)
   //   Risk.projectId    → linkObjects("Project", projectId, "HAS_RISK",   "Risk",   id)
   ```
   `upsertObject` is MERGE-based, so the script is idempotent and re-runnable.
3. Swap the provider behind the routes (above) in a branch; smoke-test the
   ontology pages.
4. Keep dual-write for one sprint if desired (call both providers in
   `upsertObject` call-sites), then drop the Palantir client + credentials.
5. New data keeps flowing: the OpenProject connector + CRUD routes write via
   the same provider (`upsertObject`/`linkObjects`), so FalkorDB stays current.

## Rollback

- The provider swap is one construction site: revert the import and the
  Palantir path is back instantly (Postgres remained the system of record
  throughout — FalkorDB is rebuildable from it at any time via the backfill
  script).
- Keep Palantir credentials parked (not deleted) until one full sprint passes
  on FalkorDB.
- If FalkorDB is down at runtime, `health()` reports it; the routes can return
  503 for ontology reads while CRUD (Postgres) continues unaffected.
