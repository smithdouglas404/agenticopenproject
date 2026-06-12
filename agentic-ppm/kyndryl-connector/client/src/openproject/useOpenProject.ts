/**
 * OpenProject bidirectional hooks for the Kyndral-365 DOSv2 client.
 *
 * ZERO-DEPENDENCY BY DESIGN: plain `fetch` + React local state — no TanStack
 * Query / axios / icon-lib imports — so this drops into any Kyndral v2 page
 * without touching the QueryClient setup. (If you later want cache sharing,
 * wrap `pushToOpenProject` / `fetchOpenProjectStatus` in useMutation/useQuery;
 * the contracts below don't change.)
 *
 * Server endpoints assumed (kyndryl-connector server work, built in parallel):
 *   PATCH /api/openproject/entities/:entityType/:externalId
 *         body {name?,description?,status?,priority?,startDate?,dueDate?,percentComplete?}
 *         → { ok, openProjectId, url }
 *   POST  /api/openproject/projects/:externalProjectId/work-packages
 *         body { subject, description?, typeName? } → { id, url }
 *   GET   /api/openproject/link/:entityType/:externalId → { url }
 *   GET   /api/openproject/status → { connected, instanceName?, version?, error? }
 *
 * ASSUMPTION (noted per spec): entities synced from OpenProject carry
 *   sourceSystem: 'openproject', externalId, lastSyncedAt
 * — stamped by the connector's syncProject upsert (server/openProjectClient.ts).
 *
 * DROP-IN: copy to <kyndral>/client/src/openproject/useOpenProject.ts
 */
import { useCallback, useEffect, useRef, useState } from "react";

// ── Types ─────────────────────────────────────────────────────────────────────

/** Fields the connector stamps on every entity it syncs from OpenProject. */
export interface OpenProjectSyncedFields {
  sourceSystem?: string | null;
  externalId?: string | number | null;
  /** ISO string (or Date if your storage layer hydrates it). */
  lastSyncedAt?: string | Date | null;
  /** Optional — some ontology objects carry their own type tag. */
  entityType?: string | null;
}

/** An entity confirmed (via the type guard) to be OpenProject-sourced. */
export interface OpenProjectEntity extends OpenProjectSyncedFields {
  sourceSystem: "openproject";
  externalId: string | number;
}

/** Writable fields on the PATCH endpoint (the bidirectional surface). */
export interface OpenProjectPushChanges {
  name?: string;
  description?: string;
  status?: string;
  priority?: string;
  /** ISO date (YYYY-MM-DD). */
  startDate?: string;
  /** ISO date (YYYY-MM-DD). */
  dueDate?: string;
  /** 0–100. */
  percentComplete?: number;
}

export interface PushResult {
  ok: boolean;
  openProjectId?: number;
  url?: string;
  error?: string;
}

export interface OpenProjectStatusResult {
  connected: boolean;
  instanceName?: string;
  version?: string;
  error?: string;
}

// ── Type guard ────────────────────────────────────────────────────────────────

/**
 * True when an entity is OpenProject-sourced (sourceSystem === 'openproject'
 * and a non-empty externalId). Use this to gate SourceBadge / write-back.
 */
export function isOpenProjectEntity(entity: unknown): entity is OpenProjectEntity {
  if (entity === null || typeof entity !== "object") return false;
  const e = entity as Record<string, unknown>;
  if (e.sourceSystem !== "openproject") return false;
  const id = e.externalId;
  return (
    (typeof id === "string" && id.length > 0) ||
    (typeof id === "number" && Number.isFinite(id))
  );
}

// ── Standalone fetchers (usable outside React, e.g. in save handlers) ─────────

const JSON_HEADERS: Record<string, string> = { "Content-Type": "application/json" };

async function readError(res: Response): Promise<string> {
  try {
    const body = (await res.json()) as { error?: string; message?: string };
    return body.error ?? body.message ?? `HTTP ${res.status}`;
  } catch {
    return `HTTP ${res.status}`;
  }
}

/**
 * Push edited fields back to OpenProject through the connector.
 * Resolves (never throws): inspect `.ok` / `.error`.
 */
export async function pushToOpenProject(
  entityType: string,
  externalId: string | number,
  changes: OpenProjectPushChanges,
): Promise<PushResult> {
  try {
    const res = await fetch(
      `/api/openproject/entities/${encodeURIComponent(entityType)}/${encodeURIComponent(String(externalId))}`,
      {
        method: "PATCH",
        headers: JSON_HEADERS,
        credentials: "include",
        body: JSON.stringify(changes),
      },
    );
    if (!res.ok) return { ok: false, error: await readError(res) };
    const data = (await res.json()) as {
      ok?: boolean;
      openProjectId?: number;
      url?: string;
      error?: string;
    };
    return {
      ok: data.ok !== false,
      openProjectId: data.openProjectId,
      url: data.url,
      error: data.error,
    };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) };
  }
}

export interface CreateWorkPackageBody {
  subject: string;
  description?: string;
  /** OpenProject type name, e.g. 'Task' | 'Milestone' | 'Phase'. */
  typeName?: string;
}

export interface CreateWorkPackageResult {
  ok: boolean;
  id?: number;
  url?: string;
  error?: string;
}

/** Create a work package in OpenProject under a synced project. */
export async function createWorkPackageInOpenProject(
  externalProjectId: string | number,
  body: CreateWorkPackageBody,
): Promise<CreateWorkPackageResult> {
  try {
    const res = await fetch(
      `/api/openproject/projects/${encodeURIComponent(String(externalProjectId))}/work-packages`,
      {
        method: "POST",
        headers: JSON_HEADERS,
        credentials: "include",
        body: JSON.stringify(body),
      },
    );
    if (!res.ok) return { ok: false, error: await readError(res) };
    const data = (await res.json()) as { id?: number; url?: string };
    return { ok: true, id: data.id, url: data.url };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) };
  }
}

/** One-shot status fetch (the hook below polls this). */
export async function fetchOpenProjectStatus(): Promise<OpenProjectStatusResult> {
  try {
    const res = await fetch("/api/openproject/status", { credentials: "include" });
    if (!res.ok) return { connected: false, error: await readError(res) };
    return (await res.json()) as OpenProjectStatusResult;
  } catch (err) {
    return {
      connected: false,
      error: err instanceof Error ? err.message : String(err),
    };
  }
}

// ── Hooks ─────────────────────────────────────────────────────────────────────

export interface UseOpenProjectLinkResult {
  /** Deep link into the OpenProject UI, or null while loading / unavailable. */
  url: string | null;
  loading: boolean;
}

/**
 * Resolve the OpenProject deep link for a synced entity.
 * Pass null/undefined for either arg to skip fetching (renders as no link) —
 * this keeps hook call order stable in components that may get non-OP entities.
 */
export function useOpenProjectLink(
  entityType: string | null | undefined,
  externalId: string | number | null | undefined,
): UseOpenProjectLinkResult {
  const [url, setUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(false);

  useEffect(() => {
    if (!entityType || externalId === null || externalId === undefined || externalId === "") {
      setUrl(null);
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);
    fetch(
      `/api/openproject/link/${encodeURIComponent(entityType)}/${encodeURIComponent(String(externalId))}`,
      { credentials: "include" },
    )
      .then(async (res) => (res.ok ? ((await res.json()) as { url?: string }) : null))
      .then((data) => {
        if (!cancelled) setUrl(data?.url ?? null);
      })
      .catch(() => {
        if (!cancelled) setUrl(null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [entityType, externalId]);

  return { url, loading };
}

export interface UseOpenProjectStatusResult {
  connected: boolean;
  instanceName: string | undefined;
  version: string | undefined;
  error: string | undefined;
  /** True until the first response arrives (and during manual refresh). */
  checking: boolean;
  /** Re-check on demand (e.g. a retry button). */
  refresh: () => void;
}

/**
 * Connection health of the OpenProject connector. Polls every `pollMs`
 * (default 60s, pass 0 to disable polling). Safe to use in many components
 * at once — it's cheap — but for an app-header dot, mount it once.
 */
export function useOpenProjectStatus(pollMs: number = 60_000): UseOpenProjectStatusResult {
  const [status, setStatus] = useState<OpenProjectStatusResult | null>(null);
  const [checking, setChecking] = useState<boolean>(true);
  const aliveRef = useRef<boolean>(true);

  const check = useCallback(() => {
    setChecking(true);
    void fetchOpenProjectStatus().then((result) => {
      if (!aliveRef.current) return;
      setStatus(result);
      setChecking(false);
    });
  }, []);

  useEffect(() => {
    aliveRef.current = true;
    check();
    let timer: ReturnType<typeof setInterval> | undefined;
    if (pollMs > 0) timer = setInterval(check, pollMs);
    return () => {
      aliveRef.current = false;
      if (timer !== undefined) clearInterval(timer);
    };
  }, [check, pollMs]);

  return {
    connected: status?.connected ?? false,
    instanceName: status?.instanceName,
    version: status?.version,
    error: status?.error,
    checking,
    refresh: check,
  };
}

// ── Small shared util ─────────────────────────────────────────────────────────

/** "3m ago" / "2h ago" / "5d ago" — for lastSyncedAt chips. */
export function formatRelativeTime(value: string | Date | null | undefined): string {
  if (value === null || value === undefined) return "unknown";
  const date = typeof value === "string" ? new Date(value) : value;
  const ms = Date.now() - date.getTime();
  if (Number.isNaN(ms)) return "unknown";
  if (ms < 0) return "just now";
  const sec = Math.floor(ms / 1000);
  if (sec < 60) return "just now";
  const min = Math.floor(sec / 60);
  if (min < 60) return `${min}m ago`;
  const hr = Math.floor(min / 60);
  if (hr < 24) return `${hr}h ago`;
  const day = Math.floor(hr / 24);
  if (day < 30) return `${day}d ago`;
  return date.toLocaleDateString();
}
