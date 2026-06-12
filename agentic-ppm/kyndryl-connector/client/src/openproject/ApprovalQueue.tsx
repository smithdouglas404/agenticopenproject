/**
 * ApprovalQueue — the human-in-the-loop inbox for agent insights and
 * recommendations, for the Kyndral HITLApprovalCenter page (or anywhere).
 *
 * The loop this renders:
 *   agents reason over the graph → findings (with evidence citations and
 *   confidence) → THIS QUEUE → a human approves/rejects → the runtime
 *   executes the gated action (OpenProject status/comments/follow-ups) AND
 *   records the decision as a training label (per-agent accuracy, severity
 *   auto-tuning). Your click teaches the system.
 *
 * Data comes through the server proxy in
 * server/routes/agentFindings.routes.ts (default /api/agent/*), so the
 * agent-runtime token stays server-side.
 *
 * DROP-IN: copy to Kyndral `client/src/openproject/ApprovalQueue.tsx` and
 * render <ApprovalQueue decidedBy={currentUser.email} /> in
 * HITLApprovalCenter. Tailwind only; no component-library dependency.
 */
import { useCallback, useEffect, useMemo, useState } from "react";

export interface AgentFinding {
  id: string;
  type: string;
  agentId: string;
  severity: "low" | "medium" | "high" | string;
  title: string;
  body: string;
  narrative?: string;
  status: string;
  nodeId?: string;
  workPackageId?: number;
  projectId?: number;
  projectName?: string;
  /** JSON string: [{entityId, metric, value}] */
  evidence?: string;
  /** 0 = unset; otherwise 0–1 */
  confidence?: number;
  createdAt: string;
  updatedAt: string;
}

interface AgentAccuracy {
  total: number;
  accuracy: number | null;
}

interface EvidenceRow {
  entityId: string;
  metric: string;
  value: string | number;
}

const SEVERITY_STYLES: Record<string, string> = {
  high: "bg-red-500/10 text-red-600 dark:text-red-300 border-red-500/30",
  medium: "bg-amber-500/10 text-amber-600 dark:text-amber-300 border-amber-500/30",
  low: "bg-sky-500/10 text-sky-600 dark:text-sky-300 border-sky-500/30",
};

function parseEvidence(raw?: string): EvidenceRow[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export interface ApprovalQueueProps {
  /** Base of the server proxy routes. */
  apiBase?: string;
  /** Recorded on the decision (e.g. the signed-in user's email). */
  decidedBy?: string;
  /** Called after any successful decision (e.g. to refresh page counters). */
  onDecided?: (finding: AgentFinding, decision: "approve" | "reject") => void;
  className?: string;
}

export function ApprovalQueue({
  apiBase = "/api/agent",
  decidedBy,
  onDecided,
  className = "",
}: ApprovalQueueProps) {
  const [findings, setFindings] = useState<AgentFinding[]>([]);
  const [accuracy, setAccuracy] = useState<Record<string, AgentAccuracy>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [deciding, setDeciding] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [findingsRes, learningRes] = await Promise.all([
        fetch(`${apiBase}/findings?status=published`),
        fetch(`${apiBase}/learning`).catch(() => null),
      ]);
      if (!findingsRes.ok) throw new Error(`findings: HTTP ${findingsRes.status}`);
      const data = await findingsRes.json();
      setFindings(Array.isArray(data) ? data : (data.findings ?? []));
      if (learningRes?.ok) {
        const learning = await learningRes.json();
        setAccuracy(learning.accuracy ?? learning ?? {});
      }
    } catch (err: any) {
      setError(err?.message ?? String(err));
    } finally {
      setLoading(false);
    }
  }, [apiBase]);

  useEffect(() => {
    void refresh();
  }, [refresh]);

  const decide = useCallback(
    async (finding: AgentFinding, decision: "approve" | "reject") => {
      setDeciding(finding.id);
      try {
        const res = await fetch(`${apiBase}/findings/${finding.id}/${decision}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(decidedBy ? { decidedBy } : {}),
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        setFindings((prev) => prev.filter((f) => f.id !== finding.id));
        onDecided?.(finding, decision);
      } catch (err: any) {
        setError(`Decision failed for "${finding.title}": ${err?.message ?? err}`);
      } finally {
        setDeciding(null);
      }
    },
    [apiBase, decidedBy, onDecided],
  );

  const sorted = useMemo(() => {
    const rank: Record<string, number> = { high: 0, medium: 1, low: 2 };
    return [...findings].sort(
      (a, b) => (rank[a.severity] ?? 3) - (rank[b.severity] ?? 3) || b.updatedAt.localeCompare(a.updatedAt),
    );
  }, [findings]);

  return (
    <div className={`flex flex-col gap-3 ${className}`}>
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-base font-semibold">Agent recommendations</h2>
          <p className="text-xs text-neutral-500 dark:text-neutral-400">
            Approving executes the gated action and trains the agent. Rejecting also trains it.
          </p>
        </div>
        <button
          type="button"
          onClick={() => void refresh()}
          className="rounded-md border border-neutral-300 px-2 py-1 text-xs hover:bg-neutral-100 dark:border-neutral-700 dark:hover:bg-neutral-800"
        >
          Refresh
        </button>
      </div>

      {error && (
        <div className="rounded-md border border-red-500/30 bg-red-500/10 px-3 py-2 text-xs text-red-600 dark:text-red-300">
          {error}
        </div>
      )}
      {loading && <div className="text-sm text-neutral-500">Loading agent findings…</div>}
      {!loading && sorted.length === 0 && !error && (
        <div className="rounded-md border border-neutral-200 px-3 py-6 text-center text-sm text-neutral-500 dark:border-neutral-800">
          No open recommendations. The portfolio is clear — or the next sweep hasn't run yet.
        </div>
      )}

      {sorted.map((finding) => {
        const evidence = parseEvidence(finding.evidence);
        const track = accuracy[finding.agentId];
        const sevClass = SEVERITY_STYLES[finding.severity] ?? SEVERITY_STYLES.low;
        return (
          <div
            key={finding.id}
            className="rounded-lg border border-neutral-200 p-3 dark:border-neutral-800"
          >
            <div className="flex flex-wrap items-center gap-2">
              <span className={`rounded-full border px-2 py-0.5 text-[11px] font-medium ${sevClass}`}>
                {finding.severity}
              </span>
              <span className="text-[11px] text-neutral-500">{finding.agentId}</span>
              {track && (
                <span
                  className="rounded-full bg-neutral-500/10 px-2 py-0.5 text-[11px] text-neutral-600 dark:text-neutral-300"
                  title="Share of this agent's resolved predictions that proved correct or were human-confirmed."
                >
                  {track.accuracy === null
                    ? `track record: n/a (${track.total} resolved)`
                    : `${Math.round(track.accuracy * 100)}% accurate over ${track.total} resolved`}
                </span>
              )}
              {typeof finding.confidence === "number" && finding.confidence > 0 && (
                <span className="rounded-full bg-violet-500/10 px-2 py-0.5 text-[11px] text-violet-600 dark:text-violet-300">
                  confidence {Math.round(finding.confidence * 100)}%
                </span>
              )}
              {finding.projectName && (
                <span className="text-[11px] text-neutral-500">· {finding.projectName}</span>
              )}
            </div>

            <h3 className="mt-2 text-sm font-semibold">{finding.title}</h3>
            <p className="mt-1 whitespace-pre-wrap text-sm text-neutral-700 dark:text-neutral-300">
              {finding.narrative || finding.body}
            </p>
            <p className="mt-1 text-[10px] uppercase tracking-wide text-neutral-400">AI narrative</p>

            {evidence.length > 0 && (
              <div className="mt-2 rounded-md bg-neutral-500/5 p-2">
                <p className="text-[10px] font-medium uppercase tracking-wide text-neutral-500">
                  Evidence (from the graph)
                </p>
                <ul className="mt-1 space-y-0.5">
                  {evidence.map((row, i) => (
                    <li key={i} className="font-mono text-[11px] text-neutral-600 dark:text-neutral-300">
                      {row.entityId} · {row.metric} = {String(row.value)}
                    </li>
                  ))}
                </ul>
              </div>
            )}

            <div className="mt-3 flex gap-2">
              <button
                type="button"
                disabled={deciding === finding.id}
                onClick={() => void decide(finding, "approve")}
                className="rounded-md bg-emerald-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-emerald-700 disabled:opacity-50"
              >
                {deciding === finding.id ? "…" : "Approve & execute"}
              </button>
              <button
                type="button"
                disabled={deciding === finding.id}
                onClick={() => void decide(finding, "reject")}
                className="rounded-md border border-neutral-300 px-3 py-1.5 text-xs font-medium hover:bg-neutral-100 disabled:opacity-50 dark:border-neutral-700 dark:hover:bg-neutral-800"
              >
                Reject
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}

export default ApprovalQueue;
