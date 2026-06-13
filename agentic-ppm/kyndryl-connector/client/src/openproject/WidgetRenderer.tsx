/**
 * WidgetRenderer — a tiny registry that maps a widget id (chosen in the
 * Ontology Mapping Studio) to a small, presentational React renderer, so a
 * mapped attribute can actually DISPLAY its value the right way.
 *
 * The flow this closes (see docs/WIDGET_CATALOG.md):
 *   source attribute (type) → ontology property → chosen widget id → THIS
 *   registry renders the value. The studio's /widgets endpoint advertises which
 *   widgets apply to which attribute types (appliesTo); here we implement them.
 *
 * Everything is pure/presentational: no data fetching, no deps beyond React.
 * Pass `renderWidget(widgetId, { label, value, type })` anywhere you have a
 * resolved value, or look one up in `WIDGET_RENDERERS`. Unknown widget ids fall
 * back to `labeled_field` so nothing ever renders blank.
 *
 * DROP-IN: copy to Kyndral `client/src/openproject/WidgetRenderer.tsx`.
 * Tailwind only; dark-mode friendly; no component-library dependency.
 */
import type { ReactNode } from "react";

/** The attribute/ontology value types the studio understands. */
export type WidgetValueType =
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

/** Props every widget renderer receives. `value` is already resolved. */
export interface WidgetProps {
  label: string;
  value: unknown;
  type: WidgetValueType;
}

export type WidgetRenderer = (props: WidgetProps) => ReactNode;

/* ------------------------------------------------------------------ helpers */

function asNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    const n = Number(value);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

/** Coerce a 0–1 or 0–100 value into a clamped 0–100 percentage. */
function asPercent(value: unknown): number {
  const n = asNumber(value) ?? 0;
  const pct = n > 0 && n <= 1 ? n * 100 : n;
  return Math.max(0, Math.min(100, pct));
}

function asText(value: unknown): string {
  if (value === null || value === undefined) return "—";
  if (typeof value === "string") return value || "—";
  if (typeof value === "number" || typeof value === "boolean") return String(value);
  try {
    return JSON.stringify(value);
  } catch {
    return String(value);
  }
}

function asList(value: unknown): string[] {
  if (Array.isArray(value)) return value.map((v) => asText(v));
  if (typeof value === "string" && value.includes(",")) return value.split(",").map((s) => s.trim());
  if (value === null || value === undefined || value === "") return [];
  return [asText(value)];
}

/** RAG band for a 0–100 percentage (red < 40, amber < 75, green otherwise). */
function ragBand(pct: number): { ring: string; bar: string; text: string } {
  if (pct < 40) return { ring: "border-red-500/40", bar: "bg-red-500", text: "text-red-600 dark:text-red-300" };
  if (pct < 75) return { ring: "border-amber-500/40", bar: "bg-amber-500", text: "text-amber-600 dark:text-amber-300" };
  return { ring: "border-emerald-500/40", bar: "bg-emerald-500", text: "text-emerald-600 dark:text-emerald-300" };
}

const FRAME = "rounded-lg border border-neutral-200 p-3 dark:border-neutral-800";
const LABEL = "text-[10px] uppercase tracking-wide text-neutral-400";

/* ----------------------------------------------------------------- widgets */

const kpi_tile: WidgetRenderer = ({ label, value }) => (
  <div className={FRAME}>
    <div className="text-2xl font-semibold tabular-nums">{asText(value)}</div>
    <div className="mt-0.5 text-xs text-neutral-500">{label}</div>
  </div>
);

const gauge: WidgetRenderer = ({ label, value }) => {
  const pct = asPercent(value);
  const band = ragBand(pct);
  return (
    <div className={FRAME}>
      <div className="flex items-center justify-between text-xs">
        <span className="text-neutral-500">{label}</span>
        <span className={`font-medium tabular-nums ${band.text}`}>{Math.round(pct)}%</span>
      </div>
      <div className="mt-1.5 h-2 w-full overflow-hidden rounded-full bg-neutral-500/15">
        <div className={`h-full ${band.bar}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
};

const progress_bar: WidgetRenderer = ({ label, value }) => {
  const pct = asPercent(value);
  return (
    <div className={FRAME}>
      <div className="flex items-center justify-between text-xs">
        <span className="text-neutral-500">{label}</span>
        <span className="font-medium tabular-nums">{Math.round(pct)}%</span>
      </div>
      <div className="mt-1.5 h-2 w-full overflow-hidden rounded-full bg-neutral-500/15">
        <div className="h-full bg-sky-500" style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
};

const rag_ring: WidgetRenderer = ({ label, value }) => {
  const pct = asPercent(value);
  const band = ragBand(pct);
  return (
    <div className={`${FRAME} flex items-center gap-3`}>
      <div
        className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-full border-4 ${band.ring} text-[11px] font-semibold tabular-nums ${band.text}`}
      >
        {Math.round(pct)}
      </div>
      <div className="min-w-0">
        <div className="truncate text-sm font-medium">{label}</div>
        <div className={`text-xs ${band.text}`}>{pct < 40 ? "Red" : pct < 75 ? "Amber" : "Green"}</div>
      </div>
    </div>
  );
};

const badge: WidgetRenderer = ({ label, value }) => (
  <div className={FRAME}>
    <div className={LABEL}>{label}</div>
    <span className="mt-1 inline-block rounded-full border border-neutral-300 px-2 py-0.5 text-[11px] font-medium dark:border-neutral-700">
      {asText(value)}
    </span>
  </div>
);

const donut: WidgetRenderer = ({ label, value }) => {
  // Simple "donut": a conic ring filled to the value's percentage.
  const pct = asPercent(value);
  return (
    <div className={`${FRAME} flex items-center gap-3`}>
      <div
        className="h-12 w-12 shrink-0 rounded-full"
        style={{ background: `conic-gradient(rgb(99 102 241) ${pct * 3.6}deg, rgb(120 120 120 / 0.15) 0deg)` }}
      >
        <div className="m-[6px] flex h-9 w-9 items-center justify-center rounded-full bg-white text-[10px] font-semibold tabular-nums dark:bg-neutral-900">
          {Math.round(pct)}%
        </div>
      </div>
      <div className="min-w-0">
        <div className="truncate text-sm font-medium">{label}</div>
        <div className="text-xs text-neutral-500">{asText(value)}</div>
      </div>
    </div>
  );
};

const flag_chip: WidgetRenderer = ({ label, value }) => {
  const on = value === true || value === "true" || value === 1 || value === "yes";
  return (
    <div className={FRAME}>
      <div className={LABEL}>{label}</div>
      <span
        className={`mt-1 inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[11px] font-medium ${
          on
            ? "border-emerald-500/40 text-emerald-600 dark:text-emerald-300"
            : "border-neutral-300 text-neutral-500 dark:border-neutral-700"
        }`}
      >
        {on ? "● yes" : "○ no"}
      </span>
    </div>
  );
};

const timeline: WidgetRenderer = ({ label, value }) => (
  <div className={FRAME}>
    <div className="flex items-center justify-between text-xs">
      <span className="text-neutral-500">{label}</span>
      <span className="font-medium">{asText(value)}</span>
    </div>
    <div className="relative mt-2 h-1.5 w-full rounded-full bg-neutral-500/15">
      <div className="absolute left-0 top-0 h-full w-1/2 rounded-full bg-indigo-500/70" />
      <div className="absolute left-1/2 top-1/2 h-2.5 w-2.5 -translate-x-1/2 -translate-y-1/2 rounded-full bg-indigo-500" />
    </div>
  </div>
);

const countdown: WidgetRenderer = ({ label, value }) => {
  const target = typeof value === "string" || typeof value === "number" ? new Date(value) : null;
  const valid = target && !Number.isNaN(target.getTime());
  const days = valid ? Math.ceil((target!.getTime() - Date.now()) / 86_400_000) : null;
  const overdue = days !== null && days < 0;
  return (
    <div className={FRAME}>
      <div className={LABEL}>{label}</div>
      {days === null ? (
        <div className="mt-1 text-sm text-neutral-500">{asText(value)}</div>
      ) : (
        <div
          className={`mt-0.5 text-xl font-semibold tabular-nums ${
            overdue ? "text-red-600 dark:text-red-300" : "text-neutral-800 dark:text-neutral-100"
          }`}
        >
          {overdue ? `${Math.abs(days)}d overdue` : `${days}d left`}
        </div>
      )}
    </div>
  );
};

const labeled_field: WidgetRenderer = ({ label, value }) => (
  <div className={FRAME}>
    <div className={LABEL}>{label}</div>
    <div className="mt-1 text-sm text-neutral-800 dark:text-neutral-100">{asText(value)}</div>
  </div>
);

const markdown_card: WidgetRenderer = ({ label, value }) => (
  <div className={FRAME}>
    <div className={LABEL}>{label}</div>
    {/* Lightweight: render text with preserved newlines (no markdown dep). */}
    <p className="mt-1 whitespace-pre-wrap text-sm text-neutral-700 dark:text-neutral-300">{asText(value)}</p>
  </div>
);

const assignee_chip: WidgetRenderer = ({ label, value }) => {
  const people = asList(value);
  const initials = (name: string) =>
    name
      .split(/\s+/)
      .map((p) => p[0])
      .filter(Boolean)
      .slice(0, 2)
      .join("")
      .toUpperCase() || "?";
  return (
    <div className={FRAME}>
      <div className={LABEL}>{label}</div>
      <div className="mt-1 flex flex-wrap items-center gap-1.5">
        {people.length === 0 && <span className="text-sm text-neutral-500">Unassigned</span>}
        {people.map((p, i) => (
          <span key={i} className="inline-flex items-center gap-1.5 rounded-full bg-neutral-500/10 py-0.5 pl-0.5 pr-2 text-[11px]">
            <span className="flex h-5 w-5 items-center justify-center rounded-full bg-indigo-500/80 text-[9px] font-semibold text-white">
              {initials(p)}
            </span>
            {p}
          </span>
        ))}
      </div>
    </div>
  );
};

/* --------------------------------------------------------------- registry */

/** id → renderer. Keep ids in sync with the /api/widgets descriptors. */
export const WIDGET_RENDERERS: Record<string, WidgetRenderer> = {
  kpi_tile,
  gauge,
  progress_bar,
  rag_ring,
  badge,
  donut,
  flag_chip,
  timeline,
  countdown,
  labeled_field,
  markdown_card,
  assignee_chip,
};

/** Stable fallback used for unknown widget ids. */
export const FALLBACK_WIDGET = "labeled_field";

/**
 * Render a value with the chosen widget. Unknown ids fall back to
 * `labeled_field` so nothing renders blank.
 */
export function renderWidget(widgetId: string | undefined, props: WidgetProps): ReactNode {
  const renderer = (widgetId && WIDGET_RENDERERS[widgetId]) || WIDGET_RENDERERS[FALLBACK_WIDGET];
  return renderer(props);
}

export default WIDGET_RENDERERS;
