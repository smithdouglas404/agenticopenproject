# The ontology layer (FalkorDB) — current state + optional URL rename

Scope: Kyndral-365 DOSv2.

## Current state

**FalkorDB is the knowledge graph and ontology layer.** The Kyndral UI reads
ontology objects (Project, Feature, Story, Task, Risk, …) through the
`OntologyDataProvider` interface, implemented by
`server/FalkorOntologyDataProvider.ts` in this connector. FalkorDB is openCypher
+ vector — one service that powers both the world-model and GraphRAG.

The agent-runtime in this repo already runs FalkorDB in production for the
OpenProject world-model — no new infra, no new vendor.

## The legacy URL stem (optional rename)

The UI route is currently `/api/palantir/ontology/*`. That URL is **purely
historical** — nothing Palantir runs behind it; it's the FalkorDB provider
above. We kept the URL stem when the backend was swapped so the 59-page UI
needed zero changes.

Two options, your call:

| Option | What | When to pick |
|---|---|---|
| **Leave as-is** | Keep `/api/palantir/ontology/*`. The URL is just a name. | Lowest risk; nothing broken. |
| **Rename to `/api/ontology/*`** | Add the new route, keep the old as an alias for a release, update UI fetches, then drop the alias. | Clean naming; ~30 min of search-and-replace in Kyndral's `client/src`. |

### If you rename: the safe rollout

> **Superseded:** the exact cutover (with the alias drop-in
> `server/routes/ontologyAlias.ts` and copy-paste ripgrep/sed commands) now lives
> in [`ONTOLOGY_RENAME.md`](./ONTOLOGY_RENAME.md). The summary below is kept for
> context.

1. In Kyndral's server, mount the same handler on **both** `/api/ontology/*` and `/api/palantir/ontology/*` (alias) — zero-downtime, both URLs work.
2. Grep the Kyndral `client/` for `/api/palantir/ontology` and replace with `/api/ontology`.
3. After a release where the new URL is in use, remove the alias.

## Method reference

`FalkorOntologyDataProvider` exposes:

| Method | Purpose |
|---|---|
| `getObjects(type, filter?, limit?)` | List objects, optional property filter |
| `getObject(type, id)` | One object by id |
| `upsertObject(type, obj)` | MERGE by id, SET += props |
| `deleteObject(type, id)` | Delete + detach relationships |
| `linkObjects(fromT, fromId, rel, toT, toId, props?)` | MERGE relationship |
| `getLinkedObjects(type, id, rel, dir)` | Traverse (out/in/both) |
| `searchObjects(type, text)` | CONTAINS over name/description (upgrade path: vector) |
| `query(cypher, params)` | Escape hatch: raw openCypher |
| `aggregate(type, groupBy, agg)` | count / sum / avg group-by |
| `health()` | Connectivity check |

Env: `FALKORDB_HOST`, `FALKORDB_PORT`, `FALKORDB_GRAPH`, `FALKORDB_PASSWORD`.

Railway IPv6 note: when `RAILWAY_*` env is present, set
`dns.setDefaultResultOrder('ipv6first')` so FalkorDB's private-network host
resolves (the agent-runtime does this automatically in `src/index.ts`).

## Data migration (if you started on Postgres ontology rows)

Walk the existing ontology table once and call `upsertObject(type, row)` for
each. The provider is idempotent and re-runnable. There is no Postgres
dependency after this — the ontology lives entirely in FalkorDB.

## Why FalkorDB earned its keep

- **openCypher.** Same query family Neo4j-style graphs use; MERGE-by-id
  upserts, relationship traversal, aggregations all map 1:1.
- **Vector index for GraphRAG.** Native vector indexing means `searchObjects`
  can graduate from CONTAINS to embedding search — agents get GraphRAG over
  the live ontology.
- **One service.** Knowledge graph + ontology + vector store all in the same
  place the agents already read from.
- **Operationally cheap.** Redis-protocol, single container, no external
  round-trip or credential surface.

## Rollback

If anything regresses, swap the route to point at whatever was there before
(the old provider class still exists in source control). Data isn't lost —
FalkorDB just stops being the read source until you point back at it.
