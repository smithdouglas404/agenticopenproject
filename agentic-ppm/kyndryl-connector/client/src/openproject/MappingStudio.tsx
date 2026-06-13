/**
 * MappingStudio — the Ontology Mapping Studio for Kyndral-365.
 *
 * The principle (see docs/ONTOLOGY_MAPPING_STUDIO.md): the ontology is the
 * UNIVERSAL MAPPER. Instead of writing N×M bespoke adapters between every source
 * (OpenProject, Jira, ADO, an MCP server…) and every consumer, each source maps
 * ONCE to the shared ontology (N + M, hub-and-spoke). This studio is where a
 * human (or a pre-match from the runtime) draws that map for a source.
 *
 * The screens are: discover → map → widget → preview → publish.
 *   discover — GET /schema lists the source's attributes (key, label, type, custom)
 *   map      — per row, pick the ontology property (GET /ontology/properties),
 *              an optional transform, a display widget (GET /widgets, filtered by
 *              the attribute type via appliesTo), and whether to sync it
 *   preview  — render the current mapping as one resolved example object
 *   publish  — POST /mapping the edited SourceMappingSet
 * Auto-fill seeds the rows from GET /mapping (the runtime pre-matches by name/type).
 *
 * Data comes through the Kyndral proxy (default /api/agent/*), the same pattern
 * as server/routes/agentFindings.routes.ts. NOTE: the proxy needs GET/POST
 * forwards for /api/openproject/schema, /api/ontology/properties, /api/widgets
 * and /api/mapping — exact router lines are in docs/ONTOLOGY_MAPPING_STUDIO.md.
 *
 * DROP-IN: copy to Kyndral `client/src/openproject/MappingStudio.tsx`. Tailwind
 * only; dark-mode friendly; no component-library dependency.
 */
import { useCallback, useEffect, useMemo, useState } from "react";

/* ----------------------------------------------------------------- types */

/** The value types the studio + widgets understand. */
export type AttributeType =
  | "string"
  | "number"
  | "percentage"
  | "currency"
  | "date"
  | "boolean"
  | "enum"
  | "list"
  | "user"
  | "duration"
  | "hierarchy"
  | "relation";

/** One source attribute, as served by GET /schema. */
export interface AttributeDescriptor {
  key: string;
  label: string;
  type: AttributeType;
  source: string;
  custom?: boolean;
  enumValues?: string[];
}

/** One ontology property, as served by GET /ontology/properties. */
export interface OntologyProperty {
  id: string; // e.g. 'pm:percentComplete'
  label: string;
  type: AttributeType;
  description?: string;
}

/** A widget descriptor, as served by GET /widgets. */
export interface WidgetDescriptor {
  id: string;
  label: string;
  appliesTo: AttributeType[];
}

/** A known value transform applied between source and ontology. */
export type TransformId = "none" | "status_map" | "priority_map" | "iso_duration_hours";

/** One attribute's mapping into the ontology. */
export interface AttributeMapping {
  sourceKey: string;
  sourceLabel: string;
  ontologyProperty: string;
  transform?: TransformId;
  widget?: string;
  synced: boolean;
}

/** The full set of mappings for one source. */
export interface SourceMappingSet {
  source: string;
  mappings: AttributeMapping[];
  updatedAt: string;
}

const TRANSFORMS: { id: TransformId; label: string }[] = [
  { id: "none", label: "none" },
  { id: "status_map", label: "status_map" },
  { id: "priority_map", label: "priority_map" },
  { id: "iso_duration_hours", label: "iso_duration_hours" },
];

/* ----------------------------------------------------------------- fetch */

async function getJSON<T>(url: string): Promise<T | null> {
  try {
    const r = await fetch(url, { headers: { Accept: "application/json" } });
    if (!r.ok) return null;
    return (await r.json()) as T;
  } catch {
    return null;
  }
}

/** Compatible-type filter for ontology suggestions (numbers ↔ numbers, etc.). */
function compatibleProperty(p: OntologyProperty, t: AttributeType): boolean {
  if (p.type === t) return true;
  const NUMERICISH: AttributeType[] = ["number", "percentage", "currency", "duration"];
  if (NUMERICISH.includes(p.type) && NUMERICISH.includes(t)) return true;
  return false;
}

const PILL =
  "rounded-full border px-2 py-0.5 text-[10px] font-medium border-neutral-300 text-neutral-500 dark:border-neutral-700";
const SELECT =
  "w-full rounded-md border border-neutral-300 bg-transparent px-2 py-1 text-xs dark:border-neutral-700";

/* ------------------------------------------------------------------ props */

export interface MappingStudioProps {
  /** Base of the server proxy that forwards to the agent-runtime. */
  apiBase?: string;
  /** Called after a successful publish (e.g. to show a toast). */
  onSaved?: (set: SourceMappingSet) => void;
  /** Called on any load/publish error. */
  onError?: (message: string) => void;
  className?: string;
}

/* -------------------------------------------------------------- component */

export function MappingStudio({
  apiBase = "/api/agent",
  onSaved,
  onError,
  className = "",
}: MappingStudioProps) {
  const [source, setSource] = useState("openproject");
  const [attributes, setAttributes] = useState<AttributeDescriptor[]>([]);
  const [properties, setProperties] = useState<OntologyProperty[]>([]);
  const [widgets, setWidgets] = useState<WidgetDescriptor[]>([]);
  const [rows, setRows] = useState<Record<string, AttributeMapping>>({});
  const [updatedAt, setUpdatedAt] = useState<string>("");
  const [discovering, setDiscovering] = useState(false);
  const [publishing, setPublishing] = useState(false);
  const [showPreview, setShowPreview] = useState(false);
  const [toast, setToast] = useState<{ kind: "ok" | "err"; text: string } | null>(null);

  const fail = useCallback(
    (message: string) => {
      setToast({ kind: "err", text: message });
      onError?.(message);
    },
    [onError],
  );

  /** Discover: schema + ontology + widgets + any pre-matched mapping. */
  const discover = useCallback(async () => {
    setDiscovering(true);
    setToast(null);
    try {
      const [schema, props, widgetsRes, mapping] = await Promise.all([
        getJSON<AttributeDescriptor[]>(`${apiBase}/openproject/schema`),
        getJSON<OntologyProperty[]>(`${apiBase}/ontology/properties`),
        getJSON<{ widgets: WidgetDescriptor[] }>(`${apiBase}/widgets`),
        getJSON<SourceMappingSet>(`${apiBase}/mapping?source=${encodeURIComponent(source)}`),
      ]);
      if (!schema) {
        fail("Could not load the source schema (GET /openproject/schema).");
        return;
      }
      setAttributes(schema);
      setProperties(props ?? []);
      setWidgets(widgetsRes?.widgets ?? []);

      // Seed rows: start from the schema, overlay any pre-matched mapping.
      const preMatched = new Map((mapping?.mappings ?? []).map((m) => [m.sourceKey, m]));
      const seeded: Record<string, AttributeMapping> = {};
      for (const attr of schema) {
        const pre = preMatched.get(attr.key);
        seeded[attr.key] = pre ?? {
          sourceKey: attr.key,
          sourceLabel: attr.label,
          ontologyProperty: "",
          transform: "none",
          widget: "",
          synced: false,
        };
      }
      setRows(seeded);
      setUpdatedAt(mapping?.updatedAt ?? new Date().toISOString());
    } finally {
      setDiscovering(false);
    }
  }, [apiBase, source, fail]);

  // Discover once on mount and whenever the source changes.
  useEffect(() => {
    void discover();
  }, [discover]);

  const setRow = useCallback((key: string, patch: Partial<AttributeMapping>) => {
    setRows((prev) => ({ ...prev, [key]: { ...prev[key], ...patch } }));
  }, []);

  /** Widgets compatible with a given attribute type (via appliesTo). */
  const widgetsForType = useCallback(
    (t: AttributeType) => widgets.filter((w) => w.appliesTo.includes(t)),
    [widgets],
  );

  /** The mapping set as it stands (only rows the user actually mapped). */
  const currentSet = useMemo<SourceMappingSet>(() => {
    const mappings = Object.values(rows).filter((m) => m.ontologyProperty || m.synced);
    return { source, mappings, updatedAt: new Date().toISOString() };
  }, [rows, source]);

  /** Preview: one resolved example object {ontologyProperty: placeholder}. */
  const previewObject = useMemo(() => {
    const obj: Record<string, string> = {};
    for (const m of currentSet.mappings) {
      if (!m.ontologyProperty) continue;
      const t = m.transform && m.transform !== "none" ? ` |> ${m.transform}` : "";
      obj[m.ontologyProperty] = `<${m.sourceLabel}>${t}`;
    }
    return obj;
  }, [currentSet]);

  const publish = useCallback(async () => {
    setPublishing(true);
    setToast(null);
    try {
      const res = await fetch(`${apiBase}/mapping`, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify(currentSet),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setToast({ kind: "ok", text: `Published ${currentSet.mappings.length} mappings for "${source}".` });
      setUpdatedAt(currentSet.updatedAt);
      onSaved?.(currentSet);
    } catch (err) {
      fail(`Publish failed: ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setPublishing(false);
    }
  }, [apiBase, currentSet, source, onSaved, fail]);

  const mappedCount = currentSet.mappings.filter((m) => m.ontologyProperty).length;

  return (
    <div className={`flex flex-col gap-4 ${className}`}>
      {/* Header: source selector + discover */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <h2 className="text-base font-semibold">🧭 Ontology Mapping Studio</h2>
          <label className="flex items-center gap-1.5 text-xs text-neutral-500">
            source
            <select
              value={source}
              onChange={(e) => setSource(e.target.value)}
              className="rounded-md border border-neutral-300 bg-transparent px-2 py-1 text-xs dark:border-neutral-700"
            >
              <option value="openproject">openproject</option>
              {/* more sources plug in here as they map to the ontology */}
            </select>
          </label>
          {updatedAt && (
            <span className="text-xs text-neutral-500">updated {new Date(updatedAt).toLocaleString()}</span>
          )}
        </div>
        <button
          type="button"
          onClick={() => void discover()}
          disabled={discovering}
          className="rounded-md border border-neutral-300 px-2.5 py-1 text-xs hover:bg-neutral-100 disabled:opacity-50 dark:border-neutral-700 dark:hover:bg-neutral-800"
        >
          {discovering ? "Discovering…" : "↻ Discover"}
        </button>
      </div>

      {toast && (
        <div
          className={`rounded-md border px-3 py-2 text-xs ${
            toast.kind === "ok"
              ? "border-emerald-500/30 bg-emerald-500/10 text-emerald-600 dark:text-emerald-300"
              : "border-red-500/30 bg-red-500/10 text-red-600 dark:text-red-300"
          }`}
        >
          {toast.text}
        </div>
      )}

      {/* Map table */}
      <div className="overflow-x-auto rounded-lg border border-neutral-200 dark:border-neutral-800">
        <table className="w-full border-collapse text-left text-xs">
          <thead className="bg-neutral-500/5 text-[10px] uppercase tracking-wide text-neutral-500">
            <tr>
              <th className="px-3 py-2 font-medium">Source attribute</th>
              <th className="px-3 py-2 font-medium">Type</th>
              <th className="px-3 py-2 font-medium">Ontology property</th>
              <th className="px-3 py-2 font-medium">Transform</th>
              <th className="px-3 py-2 font-medium">Widget</th>
              <th className="px-3 py-2 text-center font-medium">Sync</th>
            </tr>
          </thead>
          <tbody>
            {attributes.map((attr) => {
              const row = rows[attr.key];
              if (!row) return null;
              const propOptions = properties.filter((p) => compatibleProperty(p, attr.type));
              // Allow override: ensure the chosen property is selectable even if "incompatible".
              const chosen = properties.find((p) => p.id === row.ontologyProperty);
              const showChosenOutside = chosen && !propOptions.some((p) => p.id === chosen.id);
              const widgetOptions = widgetsForType(attr.type);
              return (
                <tr key={attr.key} className="border-t border-neutral-200 align-top dark:border-neutral-800">
                  <td className="px-3 py-2">
                    <div className="font-medium text-neutral-800 dark:text-neutral-100">{attr.label}</div>
                    <div className="font-mono text-[10px] text-neutral-400">{attr.key}</div>
                  </td>
                  <td className="px-3 py-2">
                    <span className={PILL}>{attr.type}</span>
                    {attr.custom && (
                      <span className="ml-1 rounded-full border border-violet-500/40 px-2 py-0.5 text-[10px] font-medium text-violet-600 dark:text-violet-300">
                        custom
                      </span>
                    )}
                  </td>
                  <td className="px-3 py-2">
                    <select
                      value={row.ontologyProperty}
                      onChange={(e) => setRow(attr.key, { ontologyProperty: e.target.value })}
                      className={SELECT}
                    >
                      <option value="">— unmapped —</option>
                      {propOptions.map((p) => (
                        <option key={p.id} value={p.id} title={p.description ?? ""}>
                          {p.label} ({p.id})
                        </option>
                      ))}
                      {showChosenOutside && chosen && (
                        <optgroup label="override (type mismatch)">
                          <option value={chosen.id}>
                            {chosen.label} ({chosen.id})
                          </option>
                        </optgroup>
                      )}
                      {properties.length > 0 && (
                        <optgroup label="all properties">
                          {properties
                            .filter((p) => !propOptions.some((c) => c.id === p.id))
                            .map((p) => (
                              <option key={`all-${p.id}`} value={p.id}>
                                {p.label} ({p.id})
                              </option>
                            ))}
                        </optgroup>
                      )}
                    </select>
                  </td>
                  <td className="px-3 py-2">
                    <select
                      value={row.transform ?? "none"}
                      onChange={(e) => setRow(attr.key, { transform: e.target.value as TransformId })}
                      className={SELECT}
                    >
                      {TRANSFORMS.map((t) => (
                        <option key={t.id} value={t.id}>
                          {t.label}
                        </option>
                      ))}
                    </select>
                  </td>
                  <td className="px-3 py-2">
                    <select
                      value={row.widget ?? ""}
                      onChange={(e) => setRow(attr.key, { widget: e.target.value })}
                      className={SELECT}
                    >
                      <option value="">— default —</option>
                      {widgetOptions.map((w) => (
                        <option key={w.id} value={w.id}>
                          {w.label}
                        </option>
                      ))}
                    </select>
                  </td>
                  <td className="px-3 py-2 text-center">
                    <input
                      type="checkbox"
                      checked={row.synced}
                      onChange={(e) => setRow(attr.key, { synced: e.target.checked })}
                      className="h-4 w-4 accent-emerald-600"
                      aria-label={`sync ${attr.label}`}
                    />
                  </td>
                </tr>
              );
            })}
            {attributes.length === 0 && !discovering && (
              <tr>
                <td colSpan={6} className="px-3 py-6 text-center text-sm text-neutral-500">
                  Nothing discovered yet. Click <span className="font-medium">Discover</span> to load the source schema.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Actions */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="text-xs text-neutral-500">
          {mappedCount} of {attributes.length} attributes mapped
        </div>
        <div className="flex gap-2">
          <button
            type="button"
            onClick={() => setShowPreview((v) => !v)}
            className="rounded-md border border-neutral-300 px-3 py-1.5 text-xs font-medium hover:bg-neutral-100 dark:border-neutral-700 dark:hover:bg-neutral-800"
          >
            {showPreview ? "Hide preview" : "Preview"}
          </button>
          <button
            type="button"
            onClick={() => void publish()}
            disabled={publishing || mappedCount === 0}
            className="rounded-md bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {publishing ? "Publishing…" : "Publish mapping"}
          </button>
        </div>
      </div>

      {/* Preview: one resolved example object */}
      {showPreview && (
        <div className="rounded-lg border border-neutral-200 p-3 dark:border-neutral-800">
          <p className="mb-2 text-[10px] uppercase tracking-wide text-neutral-500">
            Resolved example — ontologyProperty → source value placeholder
          </p>
          {Object.keys(previewObject).length === 0 ? (
            <p className="text-sm text-neutral-500">Map at least one attribute to preview.</p>
          ) : (
            <div className="grid gap-3 md:grid-cols-2">
              <table className="w-full border-collapse text-left text-xs">
                <tbody>
                  {Object.entries(previewObject).map(([prop, placeholder]) => (
                    <tr key={prop} className="border-t border-neutral-200 dark:border-neutral-800">
                      <td className="py-1 pr-3 font-mono text-[11px] text-indigo-600 dark:text-indigo-300">{prop}</td>
                      <td className="py-1 font-mono text-[11px] text-neutral-500">{placeholder}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
              <pre className="overflow-x-auto rounded-md bg-neutral-500/5 p-3 font-mono text-[11px] text-neutral-600 dark:text-neutral-300">
                {JSON.stringify(previewObject, null, 2)}
              </pre>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default MappingStudio;
