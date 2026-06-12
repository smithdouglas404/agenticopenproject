/**
 * OpenProjectEditGuard — bidirectional save for the Kyndral-365 DOSv2 client.
 *
 * The write-back half of "OpenProject as the datastore": when a user edits an
 * OpenProject-sourced entity in Kyndral, the edit (a) saves locally as the page
 * already does, then (b) pushes to OpenProject through the connector's PATCH
 * endpoint. Non-OP entities save locally only — zero behavior change.
 *
 * Three pieces, use whichever fits the page:
 *   - useBidirectionalSave(entity, opts) → { save, status, retry, … }   (hook)
 *   - <OpenProjectEditGuard entity=… onLocalSave=…>{api => …}</…>      (render-prop wrapper)
 *   - <PushStatus status=… onRetry=… />                                 (inline indicator)
 *
 * NO TOAST-LIB DEPENDENCY: surface success/failure however the host page
 * already does, via onPushed / onPushFailed callbacks (wire your toast there).
 *
 * ASSUMPTION: synced entities carry sourceSystem ('openproject'), externalId,
 * lastSyncedAt (see useOpenProject.ts header).
 *
 * DROP-IN: copy to <kyndral>/client/src/openproject/OpenProjectEditGuard.tsx
 */
import { useCallback, useRef, useState, type ReactElement, type ReactNode } from "react";
import {
  isOpenProjectEntity,
  pushToOpenProject,
  type OpenProjectPushChanges,
  type PushResult,
} from "./useOpenProject";

// ── Hook ──────────────────────────────────────────────────────────────────────

export type PushStatusValue = "idle" | "pushing" | "pushed" | "failed";

export interface UseBidirectionalSaveOptions {
  /**
   * Connector entity type for the PATCH route ('task' | 'story' | 'feature' |
   * 'epic' | 'project' | 'issue' | 'milestone' …). Falls back to
   * entity.entityType when omitted.
   */
  entityType?: string;
  /** The page's existing save (mutation, storage call, …). Runs FIRST, always. */
  onLocalSave: (changes: OpenProjectPushChanges) => void | Promise<void>;
  /** Called after a successful OpenProject push — wire your toast here. */
  onPushed?: (result: PushResult) => void;
  /** Called when the OpenProject push fails — wire your error toast here. */
  onPushFailed?: (error: string) => void;
}

export interface BidirectionalSaveApi {
  /**
   * Save locally, then (only for OpenProject-sourced entities) push the same
   * changes to OpenProject. Rejects only if the LOCAL save throws; push
   * failures are surfaced via status/onPushFailed (local data is already safe).
   */
  save: (changes: OpenProjectPushChanges) => Promise<void>;
  status: PushStatusValue;
  /** Last push error message (when status === 'failed'). */
  error: string | null;
  /** Re-push the last changes (local save already succeeded — push only). */
  retry: () => Promise<void>;
  /** Whether this entity routes back to OpenProject at all. */
  isOpenProject: boolean;
}

export function useBidirectionalSave(
  entity: unknown,
  options: UseBidirectionalSaveOptions,
): BidirectionalSaveApi {
  const { entityType, onLocalSave, onPushed, onPushFailed } = options;
  const [status, setStatus] = useState<PushStatusValue>("idle");
  const [error, setError] = useState<string | null>(null);
  const lastChangesRef = useRef<OpenProjectPushChanges | null>(null);

  const isOP = isOpenProjectEntity(entity);
  const resolvedType: string | null =
    entityType ?? (isOpenProjectEntity(entity) ? entity.entityType ?? null : null);
  const externalId: string | number | null = isOpenProjectEntity(entity)
    ? entity.externalId
    : null;

  const push = useCallback(
    async (changes: OpenProjectPushChanges): Promise<void> => {
      if (resolvedType === null || externalId === null) {
        setStatus("failed");
        setError("Missing entityType for OpenProject push");
        onPushFailed?.("Missing entityType for OpenProject push");
        return;
      }
      setStatus("pushing");
      setError(null);
      const result = await pushToOpenProject(resolvedType, externalId, changes);
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
    [resolvedType, externalId, onPushed, onPushFailed],
  );

  const save = useCallback(
    async (changes: OpenProjectPushChanges): Promise<void> => {
      // (a) local save first — Kyndral stays responsive even if OP is down.
      await onLocalSave(changes);
      // (b) write-back, only for OpenProject-sourced entities.
      if (!isOP) return;
      lastChangesRef.current = changes;
      await push(changes);
    },
    [onLocalSave, isOP, push],
  );

  const retry = useCallback(async (): Promise<void> => {
    if (lastChangesRef.current === null) return;
    await push(lastChangesRef.current);
  }, [push]);

  return { save, status, error, retry, isOpenProject: isOP };
}

// ── Inline status indicator ───────────────────────────────────────────────────

export interface PushStatusProps {
  status: PushStatusValue;
  error?: string | null;
  /** Shown as a "Retry" button when status === 'failed'. */
  onRetry?: () => void;
  className?: string;
}

/**
 * Tiny inline indicator: idle → nothing, pushing → pulse, pushed → check,
 * failed → message + Retry. Tailwind only, dark-mode friendly.
 */
export function PushStatus({ status, error, onRetry, className }: PushStatusProps): ReactElement | null {
  if (status === "idle") return null;
  const base = "inline-flex items-center gap-1.5 text-xs " + (className ?? "");
  if (status === "pushing") {
    return (
      <span className={base + " text-blue-600 dark:text-blue-300"} role="status">
        <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-blue-500" aria-hidden="true" />
        Pushing to OpenProject…
      </span>
    );
  }
  if (status === "pushed") {
    return (
      <span className={base + " text-emerald-600 dark:text-emerald-400"} role="status">
        <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M20 6 9 17l-5-5" />
        </svg>
        Synced to OpenProject
      </span>
    );
  }
  // failed
  return (
    <span className={base + " text-red-600 dark:text-red-400"} role="alert">
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
        <circle cx="12" cy="12" r="10" />
        <path d="M12 8v4" />
        <path d="M12 16h.01" />
      </svg>
      <span title={error ?? undefined}>OpenProject push failed</span>
      {onRetry !== undefined ? (
        <button
          type="button"
          onClick={() => void onRetry()}
          className="rounded border border-red-500/40 px-1.5 py-0.5 text-[11px] font-medium hover:bg-red-500/10"
        >
          Retry
        </button>
      ) : null}
    </span>
  );
}

// ── Render-prop wrapper ───────────────────────────────────────────────────────

export interface OpenProjectEditGuardProps extends UseBidirectionalSaveOptions {
  entity: unknown;
  /**
   * Render prop: receives the save API. Example:
   *   <OpenProjectEditGuard entity={task} entityType="task" onLocalSave={mutate}>
   *     {({ save, status, retry }) => (
   *       <>
   *         <TaskForm onSubmit={save} />
   *         <PushStatus status={status} onRetry={retry} />
   *       </>
   *     )}
   *   </OpenProjectEditGuard>
   */
  children: (api: BidirectionalSaveApi) => ReactNode;
  /** Auto-render <PushStatus> under the children (default true). */
  showStatus?: boolean;
}

export function OpenProjectEditGuard({
  entity,
  entityType,
  onLocalSave,
  onPushed,
  onPushFailed,
  children,
  showStatus = true,
}: OpenProjectEditGuardProps): ReactElement {
  const api = useBidirectionalSave(entity, { entityType, onLocalSave, onPushed, onPushFailed });
  return (
    <>
      {children(api)}
      {showStatus ? (
        <PushStatus status={api.status} error={api.error} onRetry={() => void api.retry()} className="mt-1" />
      ) : null}
    </>
  );
}

export default OpenProjectEditGuard;
