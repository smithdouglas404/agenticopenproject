/**
 * DecisionEditor — a Kyndral-365 drop-in that wraps the GoRules visual JDM
 * editor (`@gorules/jdm-editor`) for authoring DECISION rules.
 *
 * Rules are AUTHORED IN OPENPROJECT (the agentic_ppm module is the system of
 * record for rules). A decision rule carries a `jdm` (GoRules JSON Decision
 * Model) on its AgentRule row (kind='decision'); the agent-runtime evaluates it
 * via the GoRules ZEN engine against the entity context. See
 * docs/DECISION_ENGINE_GORULES.md for the input-context schema and the
 * {breach,severity,message,action_kind,metric,value} output contract.
 *
 * This component is the Phase-2 visual authoring surface: it renders the GoRules
 * decision-table / decision-graph editor bound to a JDM `value`, and a Save
 * button that calls `onSave(jdm)` — the caller persists the JDM back to
 * OpenProject (e.g. a PATCH /agentic_ppm/api/rules/:id write endpoint fronted by
 * a Kyndral server proxy; that write endpoint is the documented small gap, see
 * DECISION_ENGINE_GORULES.md §6). OpenProject stays the system of record;
 * Kyndral writes *into* it.
 *
 * IMPORTANT — dependency:
 *   This file imports the visual editor from `@gorules/jdm-editor`. The consuming
 *   Kyndral app must install it first:  `npm i @gorules/jdm-editor`  (and it ships
 *   a stylesheet that must be imported once — see the CSS import below).
 *   The GoRules docs export the top-level editor as `JdmEditor`; older/newer
 *   versions also expose a lower-level `DecisionGraph`. We use the documented
 *   top-level `JdmEditor` export here. If your installed version names it
 *   differently, change the import on the next line to match the version's
 *   documented top-level editor component (the props used below — value/defaultValue,
 *   onChange — are the stable surface).
 *
 * TYPES: to keep THIS file self-consistent without the dependency installed in
 * our typecheck sandbox, the `@gorules/jdm-editor` imports carry
 * `// @ts-expect-error jdm-editor types resolved in the Kyndral app`, and the
 * editor's props plus the JDM value are typed LOCALLY (`JdmEditorProps`,
 * `DecisionGraphType`) declaring only what we use. In the real Kyndral app the
 * package's own types take over (they are structurally compatible). We could not
 * typecheck against the real jdm-editor types — only these local declarations.
 *
 * DROP-IN: copy to Kyndral `client/src/openproject/DecisionEditor.tsx`, install
 * `@gorules/jdm-editor`, and render <DecisionEditor value={jdm} onSave={...} />
 * on the rule-authoring / governance page. Tailwind only for the wrapper chrome;
 * the inner editor brings its own styling.
 */

import { useCallback, useState } from "react";

/**
 * A GoRules JSON Decision Model (decision table / graph). We declare it locally
 * (opaque object) so this file is self-consistent without the `@gorules/jdm-editor`
 * package installed; in the Kyndral app the package's own `DecisionGraphType`
 * is structurally compatible.
 */
export type DecisionGraphType = Record<string, unknown>;

/**
 * The package ships a stylesheet that must be imported once in the app
 * (side-effect only). Resolved in the Kyndral app once `@gorules/jdm-editor`
 * is installed; a bare side-effect import of an unresolved module does not error
 * the typecheck (no binding is referenced), so no directive is needed here.
 */
import "@gorules/jdm-editor/dist/style.css";

/**
 * The visual JDM editor component. GoRules documents the top-level export as
 * `JdmEditor` (some versions also expose a lower-level `DecisionGraph` — if your
 * installed version differs, switch the named import accordingly). Typed locally
 * as a function component over the props we use, so this file typechecks before
 * the dependency is installed; the real component takes over in the Kyndral app.
 */
// @ts-expect-error jdm-editor types resolved in the Kyndral app (run `npm i @gorules/jdm-editor`)
import { JdmEditor as JdmEditorImport } from "@gorules/jdm-editor";

interface JdmEditorProps {
  value?: DecisionGraphType;
  defaultValue?: DecisionGraphType;
  onChange?: (graph: DecisionGraphType) => void;
  disabled?: boolean;
}
const JdmEditor = JdmEditorImport as (props: JdmEditorProps) => JSX.Element;

export interface DecisionEditorProps {
  /** The JDM to edit (GoRules JSON Decision Model). */
  value: DecisionGraphType;
  /** Fired on every edit with the updated JDM. */
  onChange?: (jdm: DecisionGraphType) => void;
  /**
   * Persist the JDM back to OpenProject (system of record). The caller wires
   * this to the rules write endpoint / proxy (see DECISION_ENGINE_GORULES.md §6).
   * May be async; the Save button shows a saving state while it resolves.
   */
  onSave?: (jdm: DecisionGraphType) => void | Promise<void>;
  /** Read-only mode (view a rule's JDM without editing). */
  readOnly?: boolean;
  className?: string;
}

/**
 * Wraps the GoRules visual JDM editor with Tailwind chrome consistent with the
 * other OpenProject UI-kit components (RulesPanel / ApprovalQueue): a header
 * strip with a "decision rule" note + Save button, then the editor canvas.
 */
export function DecisionEditor({
  value,
  onChange,
  onSave,
  readOnly = false,
  className = "",
}: DecisionEditorProps) {
  const [draft, setDraft] = useState<DecisionGraphType>(value);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<string | null>(null);

  const handleChange = useCallback(
    (graph: DecisionGraphType) => {
      setDraft(graph);
      setSavedAt(null);
      onChange?.(graph);
    },
    [onChange],
  );

  const handleSave = useCallback(async () => {
    if (!onSave) return;
    setSaving(true);
    setError(null);
    try {
      await onSave(draft);
      setSavedAt(new Date().toLocaleTimeString());
    } catch (err: any) {
      setError(err?.message ?? String(err));
    } finally {
      setSaving(false);
    }
  }, [draft, onSave]);

  return (
    <div className={`flex flex-col gap-3 ${className}`}>
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-base font-semibold">Decision rule</h2>
          <p className="text-xs text-neutral-500 dark:text-neutral-400">
            Visual GoRules JDM (decision table) · evaluated by the runtime via ZEN ·
            authored in OpenProject (system of record).
          </p>
        </div>
        {!readOnly && onSave && (
          <button
            type="button"
            disabled={saving}
            onClick={() => void handleSave()}
            className="rounded-md bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-700 disabled:opacity-50"
          >
            {saving ? "Saving…" : "Save to OpenProject"}
          </button>
        )}
      </div>

      {error && (
        <div className="rounded-md border border-red-500/30 bg-red-500/10 px-3 py-2 text-xs text-red-600 dark:text-red-300">
          {error}
        </div>
      )}
      {savedAt && !error && (
        <div className="rounded-md border border-emerald-500/30 bg-emerald-500/10 px-3 py-2 text-xs text-emerald-600 dark:text-emerald-300">
          Saved to OpenProject at {savedAt}.
        </div>
      )}

      {/* The GoRules visual decision-table / graph editor, bound to the JDM value. */}
      <div className="min-h-[480px] overflow-hidden rounded-lg border border-neutral-200 dark:border-neutral-800">
        <JdmEditor value={draft} onChange={handleChange} disabled={readOnly} />
      </div>

      <p className="text-[10px] uppercase tracking-wide text-neutral-400">
        Output contract: {"{ breach, severity?, message?, action_kind?, metric?, value? }"} ·
        see docs/DECISION_ENGINE_GORULES.md
      </p>
    </div>
  );
}

export default DecisionEditor;
