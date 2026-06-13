# Ontology Mapping Studio

The studio is where a human (or the runtime's pre-match) draws the map from a
**source** (OpenProject, and later Jira / ADO / an MCP server) into the **shared
ontology**. The UI is `client/src/openproject/MappingStudio.tsx`; the display
half is `client/src/openproject/WidgetRenderer.tsx`.

## 1. The hub-and-spoke principle (why this exists)

Without an ontology, connecting `N` sources to `M` consumers (dashboards,
agents, rules, exports) is `N × M` bespoke adapters — every new source or new
consumer multiplies the integration work.

With the ontology as the **universal mapper**, each source maps **once** into the
ontology and each consumer reads **once** from the ontology: `N + M`, not
`N × M`. The ontology is the hub; sources and consumers are spokes.

```
   Jira ─┐                          ┌─ Dashboards
   ADO  ─┤                          ├─ Mastra agents (grounded facts)
   OpenP ┼──►  ONTOLOGY (hub)  ◄────┼─ Rules engine
   MCP  ─┘     pm:percentComplete   └─ Exports / API
                pm:dueDate, …
```

Every source attribute resolves to a stable ontology property id
(e.g. `pm:percentComplete`). Consumers never learn a source's field names; they
speak ontology. Add a source → map it once. Add a consumer → it works for every
source already mapped.

## 2. The screens: discover → map → widget → preview → publish

| Step | What happens | Endpoint |
|---|---|---|
| **Discover** | Pull the source's attributes (key, label, type, custom) and the ontology + widget vocabularies; overlay any pre-matched mapping. | `GET /schema`, `GET /ontology/properties`, `GET /widgets`, `GET /mapping?source=` |
| **Map** | Per attribute row, pick the ontology property (filtered to compatible type, override allowed), an optional transform, a display widget (filtered by type via `appliesTo`), and a `synced` checkbox. | (local edit) |
| **Widget** | The widget dropdown is constrained to the attribute's type; the chosen id is what `WidgetRenderer.renderWidget()` uses to display the value. | `GET /widgets` |
| **Preview** | Render one resolved example object `{ ontologyProperty: "<source value placeholder>" }` — JSON + table, no live data. | (local) |
| **Publish** | POST the edited `SourceMappingSet`; the runtime persists it and re-syncs the graph projection. | `POST /mapping` |

Auto-fill: `GET /mapping?source=openproject` returns the runtime's pre-match
(by name + type), so most rows arrive already filled — the human just corrects
edge cases and publishes.

## 3. The data model

```ts
type AttributeType =
  | "string" | "number" | "percentage" | "currency" | "date"
  | "boolean" | "enum" | "list" | "user" | "duration"
  | "hierarchy" | "relation";

// GET /openproject/schema  →  AttributeDescriptor[]
interface AttributeDescriptor {
  key: string;            // source field key
  label: string;          // human label
  type: AttributeType;
  source: string;         // "openproject"
  custom?: boolean;       // custom field badge
  enumValues?: string[];  // for enum types
}

// GET /ontology/properties  →  OntologyProperty[]
interface OntologyProperty {
  id: string;             // "pm:percentComplete"
  label: string;
  type: AttributeType;
  description?: string;
}

// GET /widgets  →  { widgets: WidgetDescriptor[] }
interface WidgetDescriptor {
  id: string;             // "progress_bar"
  label: string;
  appliesTo: AttributeType[];
}

// GET /mapping?source=openproject  →  SourceMappingSet  (POST /mapping body)
interface AttributeMapping {
  sourceKey: string;
  sourceLabel: string;
  ontologyProperty: string;                 // "" = unmapped
  transform?: "none" | "status_map" | "priority_map" | "iso_duration_hours";
  widget?: string;                          // a WidgetDescriptor id
  synced: boolean;
}
interface SourceMappingSet {
  source: string;
  mappings: AttributeMapping[];
  updatedAt: string;                        // ISO
}
```

Transforms are the small, named value coercions applied between source and
ontology: `status_map` / `priority_map` (enum normalization to the ontology's
canonical states), `iso_duration_hours` (ISO-8601 duration → hours number).
`none` is the identity transform.

## 4. How MCP plugs in (same hub, no new code)

An MCP server is just another spoke:

- **MCP resources → ontology objects.** Each resource is a source with its own
  attributes; `GET /schema` for that source lists them, and the studio maps them
  to ontology properties exactly like OpenProject. The consumer side is
  unchanged — once mapped, agents/dashboards read ontology properties.
- **MCP tools → ontology actions.** A tool's input schema maps to an ontology
  action's parameters; the HITL/finding write-back path (the runtime) is the
  same gate. No per-tool UI code: define the source, discover, map, publish.

So onboarding an MCP server is: point the studio's source selector at it →
Discover → Map → Publish. The `N + M` math holds.

## 5. Proxy: router lines to add

The new endpoints are served by the agent-runtime and must be forwarded by the
Kyndral proxy the same way the findings routes are (token stays server-side).
Add these to `server/routes/agentFindings.routes.ts`, inside
`initAgentFindingsRoutes`, next to the existing `router.get(...)` lines:

```ts
  // --- Ontology Mapping Studio (MappingStudio.tsx) ---
  router.get("/api/agent/openproject/schema", (_req, res) =>
    void forward(res, "/api/openproject/schema"));

  router.get("/api/agent/ontology/properties", (_req, res) =>
    void forward(res, "/api/ontology/properties"));

  router.get("/api/agent/widgets", (_req, res) =>
    void forward(res, "/api/widgets"));

  router.get("/api/agent/mapping", (req: Request, res: Response) => {
    const source = typeof req.query.source === "string" ? req.query.source : "openproject";
    void forward(res, `/api/mapping?source=${encodeURIComponent(source)}`);
  });

  router.post("/api/agent/mapping", (req: Request, res: Response) =>
    void forward(res, "/api/mapping", { method: "POST", body: req.body }));
```

The client calls these as `${apiBase}/openproject/schema`,
`${apiBase}/ontology/properties`, `${apiBase}/widgets`, and
`${apiBase}/mapping` (default `apiBase = "/api/agent"`), so the runtime token is
never exposed to the browser — identical to the findings/decision proxy.

> Note: ensure the Express app has a JSON body parser mounted before this router
> (`app.use(express.json())`), since `POST /api/agent/mapping` forwards
> `req.body`.
