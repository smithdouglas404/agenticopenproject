# Source adapters & MCP — the universal-mapper plumbing

Scope: agent-runtime (the adapters) + Kyndral-365 (the Mapping Studio that
consumes them). Pairs with the runtime SourceAdapter work being built in
parallel.

## The principle

The ontology is the **universal mapper** (see `ONTOLOGY_MAPPING_STUDIO.md`):
every source maps ONCE to the shared ontology (N + M, hub-and-spoke), never
N×M bespoke adapters. To make that real, every source — OpenProject, Jira, ADO,
ServiceNow, an MCP server — is reached through ONE small interface. The Mapping
Studio then treats them all identically: discover → map → widget → preview →
publish, regardless of what's behind the adapter.

## The `SourceAdapter` interface

Every source implements the same three verbs. (Defined and registered in the
agent-runtime; the Kyndral side only ever talks to it over HTTP.)

```ts
export interface SourceAdapter {
  /** Stable id used in URLs + the studio dropdown, e.g. "openproject" | "jira". */
  readonly id: string;
  /** Human label for the dropdown. */
  readonly label: string;

  /** What fields exist? → drives the Mapping Studio "Source attribute" column. */
  discoverSchema(): Promise<AttributeDescriptor[]>;

  /** Read objects of a type (already discovered), for preview + grounding. */
  listObjects(type: string, opts?: { filter?: Record<string, unknown>; limit?: number }): Promise<SourceObject[]>;

  /** Push a mapped edit back to the source (the bidirectional half). */
  writeBack(type: string, externalId: string | number, changes: Record<string, unknown>): Promise<WriteBackResult>;
}
```

- `discoverSchema()` returns `AttributeDescriptor[]` — the same shape the studio
  already consumes (`{ key, label, type, source, custom?, enumValues? }`).
- `listObjects()` feeds the preview pane and the grounding layer (computed, never
  generated numbers).
- `writeBack()` is the per-source implementation of the PATCH the editable
  widgets call. For OpenProject this is `server/openProjectWriteback.ts`'s
  translate-then-PATCH; for others it's the source's own write API.

### MCP adapters specifically

An MCP server exposes **resources** and **tools**. The MCP adapter maps:

| MCP concept | Ontology concept | Surfaced as |
|---|---|---|
| resource (typed record) | ontology **object** | `discoverSchema()` attributes + `listObjects()` rows |
| tool (callable) | agent **action** | `GET /api/sources/:id/tools` → HITL-gated actions |

So `discoverSchema()` introspects the MCP resource shapes into
`AttributeDescriptor[]`, and the MCP tool list becomes the source's available
agent actions (each one gated through the same findings/HITL path before it
fires). `writeBack()` invokes the matching MCP tool.

## Runtime endpoints (agent-runtime)

The adapters are served over HTTP. The Kyndral proxy forwards these under
`/api/agent/*` (see `server/routes/agentFindings.routes.ts`):

| Runtime | Via Kyndral proxy | Returns |
|---|---|---|
| `GET /api/sources` | `GET /api/agent/sources` | `[{ id, label, kind }]` — registered adapters |
| `GET /api/sources/:id/schema` | `GET /api/agent/sources/:id/schema` | `AttributeDescriptor[]` for that source |
| `GET /api/sources/:id/tools` | `GET /api/agent/sources/:id/tools` | `[{ name, description, inputSchema }]` (MCP tools → actions) |

The existing `GET /api/agent/openproject/schema` stays as a convenience alias for
`sources/openproject/schema`; new sources use the generic `sources/:id/schema`.

## How the Mapping Studio lists sources

The studio's **source dropdown** is populated from `GET /api/agent/sources`
rather than a hardcoded list. Wiring (in `MappingStudio.tsx`):

```ts
// On mount, fetch the registered adapters and fill the <select>.
const sources = await getJSON<{ id: string; label: string }[]>(`${apiBase}/sources`);
// render: sources.map(s => <option value={s.id}>{s.label}</option>)
// then `discover()` calls `${apiBase}/sources/${source}/schema`
```

Today `MappingStudio.tsx` ships with `openproject` hardcoded and discovers via
`/openproject/schema`; swapping in the `/sources` list + `/sources/:id/schema`
discovery is the one change needed to make it multi-source. The proxy forwards
are already in place.

## Adding a new source (the whole job)

It is **one adapter + one register call** — no studio or UI changes:

1. **Implement** `SourceAdapter` in the agent-runtime
   (`src/sources/<name>Adapter.ts`): `discoverSchema()`, `listObjects()`,
   `writeBack()`.
2. **Register** it in the adapter registry
   (`src/sources/registry.ts` → `registerAdapter(new MyAdapter(config))`).
   It now appears in `GET /api/sources`.
3. Done. The Mapping Studio lists it in the dropdown, discovers its schema, maps
   it to the ontology, and (for `editable` attributes) writes back through
   `writeBack()`. The editable widgets (`EditableWidget.tsx`) and read-only
   widgets (`WidgetRenderer.tsx`) work unchanged because they operate on the
   ontology, not the source.

That is the payoff of the hub-and-spoke model: a new source costs one adapter,
and every consumer (studio, widgets, agents, write-back) gets it for free.
