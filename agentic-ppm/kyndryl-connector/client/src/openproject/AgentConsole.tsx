/**
 * AgentConsole — the agent-runtime console, rebuilt as a native Kyndral-365
 * React component so it lives INSIDE your UI (your design) instead of the
 * standalone `/console` page on the sidecar.
 *
 * It renders the same five sections, fed by the `/api/agent/*` proxy
 * (server/routes/agentFindings.routes.ts → the agent-runtime):
 *   1. Health pills          GET /api/agent/status
 *   2. Signal sources        GET /api/agent/roster (+ /api/agent/learning)
 *   3. Computed metrics       GET /api/agent/metrics   (computed, not generated)
 *   4. Project status         GET /api/agent/project-status
 *   5. Findings & HITL        <ApprovalQueue/>  (GET /api/agent/findings + decisions)
 *
 * DROP-IN: copy to Kyndral `client/src/openproject/AgentConsole.tsx` and render
 * <AgentConsole/> wherever the old console lived (e.g. AgentCommandCenterPage).
 * Tailwind only; no component-library dependency. Numbers are the runtime's
 * computed values — never invented here.
 */
import { useCallback, useEffect, useMemo, useState } from "react";
import { ApprovalQueue } from "./ApprovalQueue";

interface HealthCheck { name: string; ok: boolean; required?: boolean; detail?: string }
interface RosterAgent {
  id: string; name: string; domain: string; purpose: string; status: string;
  counts?: { open: number; total: number };
}
interface Metric { id: string; label: string; value: string | number; formula?: string }
interface MetricsResponse { computedAt?: string; metrics?: Metric[]; error?: string }
interface AgentAccuracy { total: number; accuracy: number | null }
interface ProjectStatusItem {
  id: string; title: string; severity: string; narrative?: string; body?: string;
  projectName?: string; nodeId?: string; updatedAt?: string;
}

const SEV_RING: Record<string, string> = {
  high: "bg-red-500/10 text-red-600 dark:text-red-300 border-red-500/30",
  critical: "bg-red-500/10 text-red-600 dark:text-red-300 border-red-500/30",
  medium: "bg-amber-500/10 text-amber-600 dark:text-amber-300 border-amber-500/30",
  warning: "bg-amber-500/10 text-amber-600 dark:text-amber-300 border-amber-500/30",
  low: "bg-sky-500/10 text-sky-600 dark:text-sky-300 border-sky-500/30",
};

async function getJSON<T>(url: string): Promise<T | null> {
  try {
    const r = await fetch(url);
    if (!r.ok) return null;
    return (await r.json()) as T;
  } catch {
    return null;
  }
}

export interface AgentConsoleProps {
  /** Base of the server proxy that forwards to the agent-runtime. */
  apiBase?: string;
  /** Recorded on HITL decisions (e.g. the signed-in user's email). */
  decidedBy?: string;
  className?: string;
}

export function AgentConsole({ apiBase = "/api/agent", decidedBy, className = "" }: AgentConsoleProps) {
  const [health, setHealth] = useState<HealthCheck[]>([]);
  const [roster, setRoster] = useState<RosterAgent[]>([]);
  const [accuracy, setAccuracy] = useState<Record<string, AgentAccuracy>>({});
  const [metrics, setMetrics] = useState<MetricsResponse>({ metrics: [] });
  const [projects, setProjects] = useState<ProjectStatusItem[]>([]);
  const [updatedAt, setUpdatedAt] = useState<string>("");
  const [sweeping, setSweeping] = useState(false);

  const refresh = useCallback(async () => {
    const [h, r, m, p, l] = await Promise.all([
      getJSON<HealthCheck[]>(`${apiBase}/status`),
      getJSON<RosterAgent[]>(`${apiBase}/roster`),
      getJSON<MetricsResponse>(`${apiBase}/metrics`),
      getJSON<ProjectStatusItem[]>(`${apiBase}/project-status`),
      getJSON<{ accuracy?: Record<string, AgentAccuracy> }>(`${apiBase}/learning`),
    ]);
    if (h) setHealth(h);
    if (r) setRoster(r);
    if (m) setMetrics(m);
    if (p) setProjects(p);
    if (l?.accuracy) setAccuracy(l.accuracy);
    setUpdatedAt(new Date().toLocaleTimeString());
  }, [apiBase]);

  useEffect(() => {
    void refresh();
    const t = setInterval(() => void refresh(), 30_000);
    return () => clearInterval(t);
  }, [refresh]);

  const runSweep = useCallback(async () => {
    setSweeping(true);
    try {
      await fetch(`${apiBase}/sweep`, { method: "POST" });
      await refresh();
    } finally {
      setSweeping(false);
    }
  }, [apiBase, refresh]);

  const sortedProjects = useMemo(
    () => [...projects].sort((a, b) => (b.updatedAt ?? "").localeCompare(a.updatedAt ?? "")),
    [projects],
  );

  return (
    <div className={`flex flex-col gap-6 ${className}`}>
      {/* Header + health pills */}
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <h2 className="text-base font-semibold">⚙︎ Agent Console</h2>
          <span className="text-xs text-neutral-500">updated {updatedAt}</span>
          <div className="flex gap-1.5">
            {health.map((c) => (
              <span
                key={c.name}
                title={c.detail ?? ""}
                className={`rounded-full border px-2 py-0.5 text-[11px] ${
                  c.ok
                    ? "border-emerald-500/40 text-emerald-600 dark:text-emerald-300"
                    : c.required
                      ? "border-red-500/40 text-red-600 dark:text-red-300"
                      : "border-amber-500/40 text-amber-600 dark:text-amber-300"
                }`}
              >
                {c.name} {c.ok ? "✓" : "✕"}
              </span>
            ))}
          </div>
        </div>
        <button
          type="button"
          onClick={() => void runSweep()}
          disabled={sweeping}
          className="rounded-md border border-neutral-300 px-2.5 py-1 text-xs hover:bg-neutral-100 disabled:opacity-50 dark:border-neutral-700 dark:hover:bg-neutral-800"
        >
          {sweeping ? "Running…" : "▸ Run sweep"}
        </button>
      </div>

      {/* Signal sources (detectors + rules — deterministic, no LLM) */}
      <section>
        <h3 className="mb-2 text-sm font-semibold">
          Signal sources{" "}
          <span className="text-xs font-normal text-neutral-500">(detectors + rules — deterministic, no LLM)</span>
        </h3>
        <div className="grid grid-cols-[repeat(auto-fill,minmax(220px,1fr))] gap-3">
          {roster.map((a) => {
            const acc = accuracy[a.id];
            return (
              <div key={a.id} className="rounded-lg border border-neutral-200 p-3 dark:border-neutral-800">
                <div className="text-sm font-semibold">{a.name}</div>
                <p className="mt-1 text-xs text-neutral-500">{a.purpose}</p>
                <div className="mt-2 flex flex-wrap items-center gap-1.5">
                  <span className="rounded-full border border-emerald-500/30 px-2 py-0.5 text-[11px] text-emerald-600 dark:text-emerald-300">
                    {a.status}
                  </span>
                  <span className="rounded-full border border-amber-500/30 px-2 py-0.5 text-[11px] text-amber-600 dark:text-amber-300">
                    {a.counts?.open ?? 0} open / {a.counts?.total ?? 0}
                  </span>
                </div>
                <p className="mt-1 text-[11px] text-neutral-400">
                  {acc
                    ? acc.accuracy === null
                      ? `learning: n/a (${acc.total} resolved)`
                      : `${Math.round(acc.accuracy * 100)}% over ${acc.total} resolved`
                    : "learning: n/a"}
                </p>
              </div>
            );
          })}
        </div>
      </section>

      {/* Computed metrics */}
      <section>
        <h3 className="mb-2 text-sm font-semibold">
          Computed metrics{" "}
          <span className="rounded-full bg-emerald-500/10 px-2 py-0.5 text-[10px] font-medium text-emerald-600 dark:text-emerald-300">
            computed, not generated
          </span>
        </h3>
        <div className="grid grid-cols-[repeat(auto-fill,minmax(150px,1fr))] gap-3">
          {(metrics.metrics ?? []).map((m) => (
            <div
              key={m.id}
              title={m.formula ?? ""}
              className="rounded-lg border border-neutral-200 p-3 dark:border-neutral-800"
            >
              <div className="text-xl font-semibold">{String(m.value)}</div>
              <div className="text-xs text-neutral-500">{m.label}</div>
            </div>
          ))}
          {(metrics.metrics ?? []).length === 0 && (
            <p className="text-sm text-neutral-500">No metrics yet (graph still syncing).</p>
          )}
        </div>
      </section>

      {/* Project status */}
      <section>
        <h3 className="mb-2 text-sm font-semibold">Project status</h3>
        <div className="flex flex-col gap-2">
          {sortedProjects.map((p) => (
            <div key={p.id} className="rounded-lg border border-neutral-200 p-3 dark:border-neutral-800">
              <span className={`rounded-full border px-2 py-0.5 text-[11px] font-medium ${SEV_RING[p.severity] ?? SEV_RING.low}`}>
                {p.severity}
              </span>
              <h4 className="mt-2 text-sm font-semibold">{p.title}</h4>
              <p className="mt-1 whitespace-pre-wrap text-sm text-neutral-700 dark:text-neutral-300">
                {p.narrative || p.body}
              </p>
              <p className="mt-1 text-[10px] uppercase tracking-wide text-neutral-400">
                AI narrative{p.projectName ? ` · ${p.projectName}` : ""}
              </p>
            </div>
          ))}
          {sortedProjects.length === 0 && (
            <p className="text-sm text-neutral-500">No project assessments yet.</p>
          )}
        </div>
      </section>

      {/* Findings & HITL — reuse the ApprovalQueue */}
      <section>
        <h3 className="mb-2 text-sm font-semibold">Findings &amp; recommendations</h3>
        <ApprovalQueue apiBase={apiBase} decidedBy={decidedBy} />
      </section>
    </div>
  );
}

export default AgentConsole;
