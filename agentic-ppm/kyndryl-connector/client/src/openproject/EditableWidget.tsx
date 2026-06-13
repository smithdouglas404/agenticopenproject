/**
 * EditableWidget — the WRITE-BACK twin of WidgetRenderer.
 *
 * WidgetRenderer.tsx displays a mapped ontology value read-only. This file adds
 * the editable variants: an inline control per attribute type that, on change,
 * PATCHes the value straight back to OpenProject (the system of record) through
 * the same connector endpoint the bidirectional save hook uses
 * (PATCH /api/openproject/entities/:entityType/:externalId — see
 * server/openProjectWriteback.ts + OpenProjectEditGuard.tsx).
 *
 * The flow this closes:
 *   ontology property (on a synced entity) → editable control → optimistic local
 *   echo → PATCH the MAPPED OpenProject field → <PushStatus> idle/saving/saved/
 *   failed+retry (the exact indicator style from OpenProjectEditGuard).
 *
 * The ontologyProperty → OpenProject field mapping is the reverse of the Mapping
 * Studio: a small built-in table covers the common ones
 * (name/description/status/priority/startDate/dueDate/percentComplete); pass a
 * `fieldMap` (e.g. derived from an AttributeMapping set) to override/extend.
 *
 * WRITABILITY: an attribute is only editable when the mapping marks it writable
 * (`editable`/`synced`). When it isn't, renderEditableWidget falls back to the
 * read-only WidgetRenderer so nothing becomes accidentally mutable.
 *
 * DROP-IN: copy to Kyndral `client/src/openproject/EditableWidget.tsx`.
 * Zero component-lib deps — plain fetch + Tailwind; dark-mode friendly.
 */
import { useCallback, useRef, useState, type ReactElement, type ReactNode } from "react";
import { PushStatus, type PushStatusValue } from "./OpenProjectEditGuard";
import {
  pushToOpenProject,
  type OpenProjectPushChanges,
  type PushResult,
} from "./useOpenProject";
import { renderWidget, type WidgetProps, type WidgetValueType } from "./WidgetRenderer";

/* --------------------------------------------------------- field mapping */

/**
 * The OpenProject-writable canonical fields (mirror of OpenProjectPushChanges /
 * the server's KyndralEntityChanges). The PATCH endpoint translates these into
 * OpenProject APIv3 (subject, description.raw, _links.status, …).
 */
export type WritebackField =
  | "name"
  | "description"
  | "status"
  | "priority"
  | "startDate"
  | "dueDate"
  | "percentComplete";

/**
 * ontologyProperty id → canonical OpenProject field. Keys are matched both
 * fully (e.g. `pm:percentComplete`) and on the trailing segment after `:`
 * (so `pm:status`, `op:status`, bare `status` all resolve to `status`).
 */
export const DEFAULT_FIELD_MAP: Record<string, WritebackField> = {
  name: "name",
  title: "name",
  subject: "name",
  description: "description",
  status: "status",
  priority: "priority",
  startDate: "startDate",
  dueDate: "dueDate",
  finishDate: "dueDate",
  percentComplete: "percentComplete",
  percentageDone: "percentComplete",
  progress: "percentComplete",
};

/** Resolve an ontologyProperty id (e.g. `pm:percentComplete`) to a writeback field. */
export function resolveWritebackField(
  ontologyProperty: string,
  fieldMap: Record<string, WritebackField> = DEFAULT_FIELD_MAP,
): WritebackField | null {
  if (fieldMap[ontologyProperty]) return fieldMap[ontologyProperty];
  const tail = ontologyProperty.includes(":")
    ? ontologyProperty.slice(ontologyProperty.lastIndexOf(":") + 1)
    : ontologyProperty;
  return fieldMap[tail] ?? null;
}

/* --------------------------------------------------------------- hook */

export interface UseAttributeWritebackOptions {
  /** Connector entity type for the PATCH route ('task'|'story'|'feature'|'project'|…). */
  entityType: string;
  /** OpenProject id Kyndral stored at sync time (the PATCH path's :externalId). */
  externalId: string | number;
  /** Ontology property being edited (mapped → an OpenProject field). */
  ontologyProperty: string;
  /** Override/extend the ontologyProperty → OpenProject field map. */
  fieldMap?: Record<string, WritebackField>;
  /** Called after a successful push — wire your toast here. */
  onPushed?: (result: PushResult) => void;
  /** Called when the push fails — wire your error toast here. */
  onPushFailed?: (error: string) => void;
}

export interface AttributeWritebackApi {
  /**
   * PATCH this one attribute's value to OpenProject. Resolves once the push
   * settles; failures surface via status/onPushFailed (never throws).
   */
  save: (value: unknown) => Promise<void>;
  status: PushStatusValue;
  error: string | null;
  /** Re-push the last value (e.g. the PushStatus "Retry" button). */
  retry: () => Promise<void>;
  /** The OpenProject field this property maps to, or null when unmappable. */
  field: WritebackField | null;
}

/** Coerce a control value into the canonical shape for a given writeback field. */
function coerceForField(field: WritebackField, value: unknown): OpenProjectPushChanges {
  switch (field) {
    case "percentComplete": {
      const n = typeof value === "number" ? value : Number(value);
      return { percentComplete: Number.isFinite(n) ? Math.max(0, Math.min(100, Math.round(n))) : 0 };
    }
    case "startDate":
    case "dueDate":
      return { [field]: value === "" || value == null ? undefined : String(value) };
    default:
      return { [field]: value == null ? "" : String(value) };
  }
}

/**
 * Single-attribute write-back. Reuses pushToOpenProject (the same PATCH the
 * bidirectional save hook calls) but scopes the change to one mapped field.
 */
export function useAttributeWriteback(options: UseAttributeWritebackOptions): AttributeWritebackApi {
  const { entityType, externalId, ontologyProperty, fieldMap, onPushed, onPushFailed } = options;
  const [status, setStatus] = useState<PushStatusValue>("idle");
  const [error, setError] = useState<string | null>(null);
  const lastValueRef = useRef<unknown>(undefined);

  const field = resolveWritebackField(ontologyProperty, fieldMap);

  const push = useCallback(
    async (value: unknown): Promise<void> => {
      if (field === null) {
        const message = `No OpenProject field mapped for "${ontologyProperty}"`;
        setStatus("failed");
        setError(message);
        onPushFailed?.(message);
        return;
      }
      setStatus("pushing");
      setError(null);
      const result = await pushToOpenProject(entityType, externalId, coerceForField(field, value));
      if (result.ok) {
        setStatus("pushed");
        onPushed?.(result);
      } else {
        const message = result.error ?? "Push to OpenProject failed";
        setStatus("failed");
        setError(message);
        onPushFailed?.(message);
      }
    },
    [field, ontologyProperty, entityType, externalId, onPushed, onPushFailed],
  );

  const save = useCallback(
    async (value: unknown): Promise<void> => {
      lastValueRef.current = value;
      await push(value);
    },
    [push],
  );

  const retry = useCallback(async (): Promise<void> => {
    if (lastValueRef.current === undefined) return;
    await push(lastValueRef.current);
  }, [push]);

  return { save, status, error, retry, field };
}

/* -------------------------------------------------------- editable props */

export interface EditableWidgetProps extends WidgetProps {
  /** Connector entity type for the PATCH route. */
  entityType: string;
  /** OpenProject id (the PATCH :externalId). */
  externalId: string | number;
  /** Ontology property being edited (mapped → an OpenProject field). */
  ontologyProperty: string;
  /** enum/status options (label/value). Required for enum-type editors. */
  options?: { label: string; value: string }[];
  /** Override/extend the ontologyProperty → OpenProject field map. */
  fieldMap?: Record<string, WritebackField>;
  /** Whether this attribute is writable at all (from the mapping). Default true. */
  editable?: boolean;
  onPushed?: (result: PushResult) => void;
  onPushFailed?: (error: string) => void;
}

const FRAME = "rounded-lg border border-neutral-200 p-3 dark:border-neutral-800";
const LABEL = "text-[10px] uppercase tracking-wide text-neutral-400";
const INPUT =
  "w-full rounded-md border border-neutral-300 bg-transparent px-2 py-1 text-sm dark:border-neutral-700 " +
  "focus:outline-none focus:ring-1 focus:ring-indigo-500";

/* ------------------------------------------------------- editable shells */

/** Common scaffold: label + control + the shared PushStatus indicator. */
function EditFrame({
  label,
  api,
  children,
}: {
  label: string;
  api: AttributeWritebackApi;
  children: ReactNode;
}): ReactElement {
  return (
    <div className={FRAME}>
      <div className="flex items-center justify-between gap-2">
        <span className={LABEL}>{label}</span>
        <PushStatus status={api.status} error={api.error} onRetry={() => void api.retry()} />
      </div>
      <div className="mt-1">{children}</div>
    </div>
  );
}

function NumberEditor(props: EditableWidgetProps): ReactElement {
  const { label, value, type } = props;
  const api = useAttributeWriteback(props);
  const [draft, setDraft] = useState<string>(value == null ? "" : String(value));
  const pct = type === "percentage";
  return (
    <EditFrame label={label} api={api}>
      <div className="flex items-center gap-2">
        <input
          type="number"
          value={draft}
          min={pct ? 0 : undefined}
          max={pct ? 100 : undefined}
          onChange={(e) => setDraft(e.target.value)}
          onBlur={() => void api.save(draft === "" ? null : Number(draft))}
          className={INPUT + " tabular-nums"}
          aria-label={label}
        />
        {pct && <span className="text-xs text-neutral-500">%</span>}
      </div>
    </EditFrame>
  );
}

function DateEditor(props: EditableWidgetProps): ReactElement {
  const { label, value } = props;
  const api = useAttributeWriteback(props);
  // Normalize to YYYY-MM-DD for the native date input.
  const initial = typeof value === "string" ? value.slice(0, 10) : "";
  const [draft, setDraft] = useState<string>(initial);
  return (
    <EditFrame label={label} api={api}>
      <input
        type="date"
        value={draft}
        onChange={(e) => {
          setDraft(e.target.value);
          void api.save(e.target.value === "" ? null : e.target.value);
        }}
        className={INPUT}
        aria-label={label}
      />
    </EditFrame>
  );
}

function EnumEditor(props: EditableWidgetProps): ReactElement {
  const { label, value, options = [] } = props;
  const api = useAttributeWriteback(props);
  const current = value == null ? "" : String(value);
  // Make sure the current value is selectable even if it's not in options.
  const hasCurrent = options.some((o) => o.value === current);
  return (
    <EditFrame label={label} api={api}>
      <select
        value={current}
        onChange={(e) => void api.save(e.target.value)}
        className={INPUT}
        aria-label={label}
      >
        {!hasCurrent && current !== "" && <option value={current}>{current}</option>}
        {!hasCurrent && current === "" && <option value="">— select —</option>}
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </EditFrame>
  );
}

function BooleanEditor(props: EditableWidgetProps): ReactElement {
  const { label, value } = props;
  const api = useAttributeWriteback(props);
  const on = value === true || value === "true" || value === 1 || value === "yes";
  return (
    <EditFrame label={label} api={api}>
      <button
        type="button"
        role="switch"
        aria-checked={on}
        aria-label={label}
        onClick={() => void api.save(!on)}
        className={`relative inline-flex h-5 w-9 items-center rounded-full transition-colors ${
          on ? "bg-emerald-500" : "bg-neutral-300 dark:bg-neutral-700"
        }`}
      >
        <span
          className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
            on ? "translate-x-4" : "translate-x-0.5"
          }`}
        />
      </button>
    </EditFrame>
  );
}

function StringEditor(props: EditableWidgetProps): ReactElement {
  const { label, value } = props;
  const api = useAttributeWriteback(props);
  const [draft, setDraft] = useState<string>(value == null ? "" : String(value));
  return (
    <EditFrame label={label} api={api}>
      <input
        type="text"
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onBlur={() => void api.save(draft)}
        className={INPUT}
        aria-label={label}
      />
    </EditFrame>
  );
}

/* ------------------------------------------------------------ registry */

export type EditableWidgetRenderer = (props: EditableWidgetProps) => ReactElement;

/** Editable renderers keyed by attribute/value type. */
export const EDITABLE_WIDGETS: Record<WidgetValueType, EditableWidgetRenderer | null> = {
  number: NumberEditor,
  percentage: NumberEditor,
  currency: NumberEditor,
  duration: NumberEditor,
  date: DateEditor,
  enum: EnumEditor,
  boolean: BooleanEditor,
  string: StringEditor,
  // Not directly editable here → fall back to the read-only widget.
  list: null,
  user: null,
  hierarchy: null,
  relation: null,
};

/**
 * Render an EDITABLE variant for a mapped attribute. The first argument accepts
 * a widget id (e.g. "gauge") or a value type ("percentage") for symmetry with
 * renderWidget; the value `type` ultimately selects the control.
 *
 * Falls back to the read-only WidgetRenderer when:
 *   - `editable` is false (the mapping marks the attribute read-only), or
 *   - the type has no editable variant (list/user/hierarchy/relation), or
 *   - the ontologyProperty doesn't resolve to a writable OpenProject field.
 */
export function renderEditableWidget(
  widgetIdOrType: string | undefined,
  props: EditableWidgetProps,
): ReactNode {
  const readOnly = (): ReactNode =>
    renderWidget(widgetIdOrType, { label: props.label, value: props.value, type: props.type });

  if (props.editable === false) return readOnly();
  if (resolveWritebackField(props.ontologyProperty, props.fieldMap) === null) return readOnly();

  const Editor = EDITABLE_WIDGETS[props.type];
  if (!Editor) return readOnly();
  return <Editor {...props} />;
}

export default EDITABLE_WIDGETS;
