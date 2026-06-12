/**
 * OpenProjectPanel — collapsible "System of Work" panel for ProjectDetailPage
 * (Kyndral-365 DOSv2 client).
 *
 * Shows, for an OpenProject-synced project:
 *   - connection status dot (live, via useOpenProjectStatus)
 *   - "Open in OpenProject" deep-link button
 *   - last-sync time
 *   - "Create work package in OpenProject" mini-form (subject + Task/Milestone/
 *     Phase type select) → POST /api/openproject/projects/:id/work-packages
 *   - OPTIONAL embedded agent console iframe: pass `consoleUrl` (the
 *     agent-runtime sidecar's /console) and it renders consoleUrl + '?embed=1'
 *     — the console supports chromeless embed mode.
 *
 * Also exports OpenProjectStatusDot — the tiny header dot. Mount it ONCE in the
 * app shell header so every page shows sync health (see
 * docs/UI_BIDIRECTIONAL_WIRING_MAP.md "Global" section).
 *
 * Tailwind only, no icon/ui-lib imports, dark-mode friendly.
 *
 * ASSUMPTION: synced entities carry sourceSystem ('openproject'), externalId,
 * lastSyncedAt (see useOpenProject.ts header).
 *
 * DROP-IN: copy to <kyndral>/client/src/openproject/OpenProjectPanel.tsx
 */
import { useState, type FormEvent, type ReactElement } from "react";
import {
  createWorkPackageInOpenProject,
  formatRelativeTime,
  isOpenProjectEntity,
  useOpenProjectLink,
  useOpenProjectStatus,
  type CreateWorkPackageResult,
} from "./useOpenProject";

// ── OpenProjectStatusDot (app-header global indicator) ────────────────────────

export interface OpenProjectStatusDotProps {
  className?: string;
  /** Show "OpenProject" label text next to the dot (default false: dot only). */
  showLabel?: boolean;
}

/**
 * Tiny status dot for the app header: green = connected, red = disconnected,
 * amber pulse = checking. Tooltip carries the instance name / error.
 */
export function OpenProjectStatusDot({ className, showLabel = false }: OpenProjectStatusDotProps): ReactElement {
  const { connected, instanceName, error, checking } = useOpenProjectStatus();
  const dotClass = checking
    ? "bg-amber-400 animate-pulse"
    : connected
      ? "bg-emerald-500"
      : "bg-red-500";
  const label = checking
    ? "Checking OpenProject connection…"
    : connected
      ? `OpenProject connected${instanceName !== undefined ? ` — ${instanceName}` : ""}`
      : `OpenProject disconnected${error !== undefined ? ` — ${error}` : ""}`;
  return (
    <span
      title={label}
      className={"inline-flex items-center gap-1.5 " + (className ?? "")}
      role="status"
      aria-label={label}
    >
      <span className={`h-2 w-2 rounded-full ${dotClass}`} aria-hidden="true" />
      {showLabel ? (
        <span className="text-xs text-neutral-500 dark:text-neutral-400">OpenProject</span>
      ) : null}
    </span>
  );
}

// ── Panel ─────────────────────────────────────────────────────────────────────

type WorkPackageTypeName = "Task" | "Milestone" | "Phase";
const WP_TYPES: readonly WorkPackageTypeName[] = ["Task", "Milestone", "Phase"];

export interface OpenProjectPanelProps {
  /**
   * The project entity (used for lastSyncedAt + to self-gate: panel renders a
   * "not synced" note for non-OP projects).
   */
  entity: unknown;
  /**
   * OpenProject project id/identifier for the create-WP endpoint. Falls back
   * to entity.externalId when the entity is OpenProject-sourced.
   */
  externalProjectId?: string | number;
  /**
   * Agent console URL (agent-runtime sidecar /console). When provided, an
   * iframe of consoleUrl + '?embed=1' is rendered inside the panel.
   */
  consoleUrl?: string;
  defaultOpen?: boolean;
  /** Hook your query invalidation / toast here after a WP is created. */
  onWorkPackageCreated?: (result: CreateWorkPackageResult) => void;
  className?: string;
}

export function OpenProjectPanel({
  entity,
  externalProjectId,
  consoleUrl,
  defaultOpen = false,
  onWorkPackageCreated,
  className,
}: OpenProjectPanelProps): ReactElement {
  const [open, setOpen] = useState<boolean>(defaultOpen);
  const { connected, instanceName, checking } = useOpenProjectStatus();

  const op = isOpenProjectEntity(entity) ? entity : null;
  const projectId: string | number | null = externalProjectId ?? op?.externalId ?? null;
  const { url: deepLink } = useOpenProjectLink(projectId !== null ? "project" : null, projectId);

  // mini-form state
  const [subject, setSubject] = useState<string>("");
  const [typeName, setTypeName] = useState<WorkPackageTypeName>("Task");
  const [creating, setCreating] = useState<boolean>(false);
  const [created, setCreated] = useState<CreateWorkPackageResult | null>(null);

  const handleCreate = async (e: FormEvent<HTMLFormElement>): Promise<void> => {
    e.preventDefault();
    if (projectId === null || subject.trim().length === 0 || creating) return;
    setCreating(true);
    setCreated(null);
    const result = await createWorkPackageInOpenProject(projectId, {
      subject: subject.trim(),
      typeName,
    });
    setCreating(false);
    setCreated(result);
    if (result.ok) {
      setSubject("");
      onWorkPackageCreated?.(result);
    }
  };

  const dotClass = checking ? "bg-amber-400 animate-pulse" : connected ? "bg-emerald-500" : "bg-red-500";

  return (
    <section
      className={
        "rounded-lg border border-neutral-200 bg-white dark:border-neutral-800 dark:bg-neutral-900 " +
        (className ?? "")
      }
    >
      {/* Header / toggle */}
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
        className="flex w-full items-center gap-2 px-4 py-3 text-left"
      >
        <span className={`h-2 w-2 rounded-full ${dotClass}`} aria-hidden="true" />
        <span className="text-sm font-semibold text-neutral-900 dark:text-neutral-100">
          OpenProject
        </span>
        <span className="text-xs text-neutral-500 dark:text-neutral-400">
          {checking
            ? "checking…"
            : connected
              ? (instanceName ?? "connected")
              : "disconnected"}
        </span>
        <span className="ml-auto text-neutral-400" aria-hidden="true">
          <svg
            width="14"
            height="14"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            strokeLinejoin="round"
            className={open ? "rotate-180 transition-transform" : "transition-transform"}
          >
            <path d="m6 9 6 6 6-6" />
          </svg>
        </span>
      </button>

      {open ? (
        <div className="space-y-4 border-t border-neutral-200 px-4 py-4 dark:border-neutral-800">
          {op === null && projectId === null ? (
            <p className="text-xs text-neutral-500 dark:text-neutral-400">
              This project is not synced from OpenProject. Connect it via IntegrationManagement
              (adapter type &quot;openproject&quot;) to enable bidirectional sync.
            </p>
          ) : (
            <>
              {/* Deep link + last sync */}
              <div className="flex flex-wrap items-center gap-3">
                {deepLink !== null ? (
                  <a
                    href={deepLink}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1.5 rounded-md border border-blue-500/30 bg-blue-500/10 px-3 py-1.5 text-xs font-medium text-blue-600 hover:bg-blue-500/20 dark:text-blue-300"
                  >
                    Open in OpenProject
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                      <path d="M15 3h6v6" />
                      <path d="M10 14 21 3" />
                      <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
                    </svg>
                  </a>
                ) : null}
                <span className="text-xs text-neutral-500 dark:text-neutral-400">
                  Last sync: {formatRelativeTime(op?.lastSyncedAt)}
                </span>
              </div>

              {/* Create work package mini-form */}
              <form onSubmit={(e) => void handleCreate(e)} className="space-y-2">
                <label
                  htmlFor="op-wp-subject"
                  className="block text-xs font-medium text-neutral-700 dark:text-neutral-300"
                >
                  Create work package in OpenProject
                </label>
                <div className="flex flex-wrap gap-2">
                  <input
                    id="op-wp-subject"
                    type="text"
                    value={subject}
                    onChange={(e) => setSubject(e.target.value)}
                    placeholder="Subject"
                    className="min-w-[180px] flex-1 rounded-md border border-neutral-300 bg-transparent px-2.5 py-1.5 text-xs text-neutral-900 placeholder:text-neutral-400 dark:border-neutral-700 dark:text-neutral-100"
                  />
                  <select
                    aria-label="Work package type"
                    value={typeName}
                    onChange={(e) => setTypeName(e.target.value as WorkPackageTypeName)}
                    className="rounded-md border border-neutral-300 bg-transparent px-2 py-1.5 text-xs text-neutral-900 dark:border-neutral-700 dark:bg-neutral-900 dark:text-neutral-100"
                  >
                    {WP_TYPES.map((t) => (
                      <option key={t} value={t}>
                        {t}
                      </option>
                    ))}
                  </select>
                  <button
                    type="submit"
                    disabled={creating || subject.trim().length === 0 || !connected}
                    className="rounded-md bg-blue-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-700 disabled:opacity-50"
                  >
                    {creating ? "Creating…" : "Create"}
                  </button>
                </div>
                {created !== null ? (
                  created.ok ? (
                    <p className="text-xs text-emerald-600 dark:text-emerald-400">
                      Created work package #{created.id}.{" "}
                      {created.url !== undefined ? (
                        <a href={created.url} target="_blank" rel="noopener noreferrer" className="underline">
                          View in OpenProject
                        </a>
                      ) : null}
                    </p>
                  ) : (
                    <p className="text-xs text-red-600 dark:text-red-400" role="alert">
                      Failed: {created.error ?? "unknown error"}
                    </p>
                  )
                ) : null}
              </form>
            </>
          )}

          {/* Embedded agent console (sidecar /console supports ?embed=1) */}
          {consoleUrl !== undefined ? (
            <div>
              <p className="mb-1 text-xs font-medium text-neutral-700 dark:text-neutral-300">
                Agent console
              </p>
              <iframe
                src={`${consoleUrl}${consoleUrl.includes("?") ? "&" : "?"}embed=1`}
                title="Agentic PPM agent console"
                className="h-80 w-full rounded-md border border-neutral-200 dark:border-neutral-800"
              />
            </div>
          ) : null}
        </div>
      ) : null}
    </section>
  );
}

export default OpenProjectPanel;
