# Widget catalog

Once an attribute is mapped to an ontology property, a **widget** decides how its
value is shown. The studio constrains the widget dropdown to the attribute's
type (via each widget's `appliesTo`), and
`client/src/openproject/WidgetRenderer.tsx` actually renders it.

## 1. Attribute type → widget options

The `GET /widgets` endpoint advertises `appliesTo` per widget; this is the
intended mapping (some widgets are aspirational and degrade to the implemented
set below — see §2):

| Attribute type | Widget options |
|---|---|
| `number` | `kpi_tile`, `gauge`, `sparkline` |
| `percentage` | `progress_bar`, `rag_ring`, `gauge` |
| `currency` | `kpi_tile` |
| `date` | `timeline`, `gantt`, `countdown` |
| `enum` | `badge`, `donut`, `kanban` |
| `boolean` | `flag_chip` |
| `hierarchy` | `wbs_tree` |
| `relation` | `dependency_graph` |
| `user` | `assignee_chip` |
| `list` | `assignee_chip`, `heatmap` |
| `duration` | `kpi_tile`, `countdown` |
| `string` | `labeled_field`, `markdown_card` |

## 2. What `WidgetRenderer` implements today

`WidgetRenderer.tsx` ships lightweight, zero-dependency, pure-presentational
versions of these widget ids:

| Widget id | Renders |
|---|---|
| `kpi_tile` | big number + label |
| `gauge` | RAG-banded horizontal bar with % |
| `progress_bar` | sky bar with % |
| `rag_ring` | colored ring (Red/Amber/Green) + label |
| `badge` | pill for an enum/string value |
| `donut` | conic-gradient donut filled to % |
| `flag_chip` | yes/no chip for booleans |
| `timeline` | single timeline bar with a marker |
| `countdown` | days left / overdue from a date |
| `labeled_field` | label + plain value (the fallback) |
| `markdown_card` | label + multi-line text (newlines preserved) |
| `assignee_chip` | initials avatars for user/list values |

Widgets in §1 that aren't in this table (`sparkline`, `gantt`, `kanban`,
`wbs_tree`, `dependency_graph`, `heatmap`) are catalog placeholders; until a
renderer is registered for them, `renderWidget()` falls back to `labeled_field`
so the value is never blank. Add them as described in §4.

## 3. How ids map to components

The registry is a plain object:

```ts
import { renderWidget, WIDGET_RENDERERS } from "./WidgetRenderer";

// WIDGET_RENDERERS: Record<string, (props: WidgetProps) => ReactNode>
// WidgetProps = { label: string; value: unknown; type: WidgetValueType }

// Render a resolved value with the widget chosen in the studio:
renderWidget(mapping.widget, { label: attr.label, value: resolved, type: attr.type });
```

`renderWidget(widgetId, props)` looks `widgetId` up in `WIDGET_RENDERERS`; an
unknown or `undefined` id falls back to `FALLBACK_WIDGET` (`labeled_field`).
Each renderer coerces `value` defensively (`asNumber`/`asPercent`/`asList`), so
passing a string `"0.42"` to `gauge` or an array to `assignee_chip` is safe.

## 4. Adding a new widget

1. **Implement a renderer** in `WidgetRenderer.tsx`:
   ```ts
   const sparkline: WidgetRenderer = ({ label, value }) => (
     <div className={FRAME}>
       <div className={LABEL}>{label}</div>
       {/* draw value... Tailwind only, no deps */}
     </div>
   );
   ```
2. **Register it** in `WIDGET_RENDERERS`:
   ```ts
   export const WIDGET_RENDERERS = { /* …existing…, */ sparkline };
   ```
3. **Advertise it** from the runtime's `GET /widgets` with the right `appliesTo`
   so it appears in the studio's widget dropdown for compatible attributes:
   ```json
   { "id": "sparkline", "label": "Sparkline", "appliesTo": ["number"] }
   ```

Keep renderers pure (no fetching), Tailwind-only, dark-mode friendly, and
defensive about `value`'s runtime type — that's the whole contract.
