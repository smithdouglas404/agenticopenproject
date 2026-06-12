/**
 * Generative-UI widgets for the agent chat — pure presentational React +
 * Tailwind, typed to the tool outputs of ../server/tools.ts.
 *
 * The chat (AgenticChat.tsx) maps streamed tool parts onto these:
 *   tool-getPortfolioMetrics → <MetricsGrid/>      tool-getFindings  → <FindingCard/> list
 *   tool-getAgentTrackRecord → <TrackRecordList/>  tool-getAgentRoster → <RosterList/>
 *   tool-getProjectStatus    → <ProjectStatusList/> tool-triggerSweep → <SweepResult/>
 *
 * Everything rendered here is STRUCTURED tool output — numbers come from the
 * runtime's computed endpoints, never from the LLM's text. Hence the
 * "computed" tags and formula tooltips: every figure on screen is auditable.
 *
 * No icon/toast libraries; inline SVG only; dark-mode-friendly Tailwind.
 */

// ── Types mirrored from ../server/tools.ts (keep in sync) ────────────────────

export interface Metric {
  id: string;
  label: string;
  value: number | string | unknown;
  computedAt: string;
  formula: string;
}

export interface EvidenceItem {
  entityId: string;
  metric: string;
  value: string;
}

export interface FindingView {
  id: string;
  agentId: string;
  type: string;
  severity: string;
  status: string;
  title: string;
  summary: string;
  isNarrative: boolean;
  confidence: number;
  evidence: EvidenceItem[];
  projectId?: number;
  projectName?: string;
  workPackageId?: number;
  updatedAt: string;
  decidedBy?: string;
}

export interface TrackRecordEntry {
  agentId: string;
  name: string;
  total: number;
  correct: number;
  incorrect: number;
  humanConfirmed: number;
  humanRejected: number;
  accuracy: number | null;
}

export interface ProjectStatusItem {
  projectId?: number;
  projectName?: string;
  severity: string;
  title: string;
  summary: string;
  metrics: Metric[];
  updatedAt: string;
}

export interface RosterAgentView {
  id: string;
  name: string;
  domain: string;
  purpose: string;
  owns: string[];
  status: string;
  counts: { open: number; total: number };
}

export interface SweepResultData {
  detected: number;
  newFindings: number;
  published: number;
}

// ── Shared bits ──────────────────────────────────────────────────────────────

const SEVERITY_STYLES: Record<string, string> = {
  high: "bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-300",
  medium: "bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-300",
  low: "bg-sky-100 text-sky-700 dark:bg-sky-950 dark:text-sky-300",
};

function SeverityBadge({ severity }: { severity: string }) {
  const style = SEVERITY_STYLES[severity] ?? "bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300";
  return (
    <span className={`inline-block rounded px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wide ${style}`}>
      {severity}
    </span>
  );
}

/** "computed, not generated" — the two-channel tag. */
function ComputedTag() {
  return (
    <span className="inline-flex items-center gap-1 rounded bg-emerald-100 px-1.5 py-0.5 text-[10px] font-medium text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300">
      <svg viewBox="0 0 12 12" className="h-2.5 w-2.5" fill="none" stroke="currentColor" strokeWidth="2">
        <path d="M2 6.5l2.5 2.5L10 3.5" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      computed
    </span>
  );
}

function NarrativeTag() {
  return (
    <span className="inline-block rounded bg-violet-100 px-1.5 py-0.5 text-[10px] font-medium text-violet-700 dark:bg-violet-950 dark:text-violet-300">
      AI narrative
    </span>
  );
}

// ── <MetricsGrid metrics/> ───────────────────────────────────────────────────

/**
 * Portfolio metrics as value cards. Scalar metrics show their value; list
 * metrics show their row count. Hovering a card reveals the formula
 * (auditability: every number traces to its Cypher one-liner).
 */
export function MetricsGrid({ metrics, computedAt }: { metrics: Metric[]; computedAt?: string }) {
  if (metrics.length === 0) {
    return <EmptyNote text="No computed metrics available (graph empty or unreachable)." />;
  }
  return (
    <div className="my-2">
      <div className="mb-1.5 flex items-center gap-2">
        <ComputedTag />
        {computedAt && (
          <span className="text-[10px] text-zinc-400 dark:text-zinc-500">as of {formatTime(computedAt)}</span>
        )}
      </div>
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        {metrics.map((m) => {
          const scalar = typeof m.value === "number" || typeof m.value === "string";
          const display = scalar
            ? String(m.value)
            : Array.isArray(m.value)
              ? `${m.value.length} rows`
              : "—";
          return (
            <div
              key={m.id}
              title={`[${m.id}] formula: ${m.formula}`}
              className="cursor-help rounded-lg border border-zinc-200 bg-white p-2.5 dark:border-zinc-700 dark:bg-zinc-900"
            >
              <div className="text-lg font-semibold tabular-nums text-zinc-900 dark:text-zinc-100">{display}</div>
              <div className="truncate text-[11px] text-zinc-500 dark:text-zinc-400">{m.label}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── <FindingCard finding/> ───────────────────────────────────────────────────

/**
 * One agent finding: severity, summary (tagged "AI narrative" when it is one),
 * evidence citations ("entityId · metric = value"), and a confidence bar.
 */
export function FindingCard({ finding }: { finding: FindingView }) {
  const pct = Math.round(Math.max(0, Math.min(1, finding.confidence)) * 100);
  return (
    <div className="my-2 rounded-lg border border-zinc-200 bg-white p-3 dark:border-zinc-700 dark:bg-zinc-900">
      <div className="flex flex-wrap items-center gap-2">
        <SeverityBadge severity={finding.severity} />
        <span className="text-[10px] text-zinc-400 dark:text-zinc-500">
          {finding.agentId} · {finding.type} · {finding.status}
        </span>
        {finding.projectName && (
          <span className="text-[10px] text-zinc-400 dark:text-zinc-500">· {finding.projectName}</span>
        )}
      </div>
      <div className="mt-1 text-sm font-medium text-zinc-900 dark:text-zinc-100">{finding.title}</div>
      <div className="mt-1 text-xs leading-relaxed text-zinc-600 dark:text-zinc-300">
        {finding.isNarrative && (
          <span className="mr-1.5 align-middle">
            <NarrativeTag />
          </span>
        )}
        {finding.summary}
      </div>

      {finding.evidence.length > 0 && (
        <ul className="mt-2 space-y-0.5">
          {finding.evidence.map((e, i) => (
            <li key={i} className="font-mono text-[11px] text-zinc-500 dark:text-zinc-400">
              <span className="text-zinc-400 dark:text-zinc-500">⌁</span> {e.entityId} · {e.metric} = {e.value}
            </li>
          ))}
        </ul>
      )}

      <div className="mt-2 flex items-center gap-2">
        <div className="h-1.5 w-28 overflow-hidden rounded-full bg-zinc-200 dark:bg-zinc-700">
          <div
            className={`h-full rounded-full ${pct >= 70 ? "bg-emerald-500" : pct >= 40 ? "bg-amber-500" : "bg-zinc-400"}`}
            style={{ width: `${pct}%` }}
          />
        </div>
        <span className="text-[10px] text-zinc-400 dark:text-zinc-500">
          {finding.confidence > 0 ? `confidence ${pct}%` : "confidence not reported"}
        </span>
        {finding.decidedBy && (
          <span className="text-[10px] text-zinc-400 dark:text-zinc-500">· decided by {finding.decidedBy}</span>
        )}
      </div>
    </div>
  );
}

// ── <TrackRecordList accuracy/> ──────────────────────────────────────────────

/**
 * Per-agent provable track record. "84% accurate over 12 resolved" — or an
 * honest "no track record yet" when fewer than 3 predictions are resolved.
 */
export function TrackRecordList({ accuracy }: { accuracy: TrackRecordEntry[] }) {
  if (accuracy.length === 0) {
    return <EmptyNote text="No resolved predictions yet — track records build as outcomes land." />;
  }
  return (
    <div className="my-2 space-y-1.5">
      {accuracy.map((a) => (
        <div
          key={a.agentId}
          className="flex items-center gap-3 rounded-lg border border-zinc-200 bg-white px-3 py-2 dark:border-zinc-700 dark:bg-zinc-900"
        >
          <div className="min-w-0 flex-1">
            <div className="truncate text-sm font-medium text-zinc-900 dark:text-zinc-100">{a.name}</div>
            <div className="text-[11px] text-zinc-500 dark:text-zinc-400">
              {a.correct + a.humanConfirmed} confirmed · {a.incorrect + a.humanRejected} wrong ·{" "}
              {a.humanConfirmed + a.humanRejected} human-labeled
            </div>
          </div>
          {a.accuracy !== null ? (
            <div className="text-right">
              <div className="text-base font-semibold tabular-nums text-zinc-900 dark:text-zinc-100">
                {Math.round(a.accuracy * 100)}%
              </div>
              <div className="text-[10px] text-zinc-400 dark:text-zinc-500">over {a.total} resolved</div>
            </div>
          ) : (
            <div className="text-right text-[11px] text-zinc-400 dark:text-zinc-500">
              n/a
              <div className="text-[10px]">&lt;3 resolved</div>
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

// ── <RosterList agents/> ─────────────────────────────────────────────────────

/** The agent roster with open/total finding counts. */
export function RosterList({ agents }: { agents: RosterAgentView[] }) {
  if (agents.length === 0) return <EmptyNote text="No agents registered." />;
  return (
    <div className="my-2 grid grid-cols-1 gap-1.5 sm:grid-cols-2">
      {agents.map((a) => (
        <div key={a.id} className="rounded-lg border border-zinc-200 bg-white px-3 py-2 dark:border-zinc-700 dark:bg-zinc-900">
          <div className="flex items-center justify-between gap-2">
            <span className="truncate text-sm font-medium text-zinc-900 dark:text-zinc-100">{a.name}</span>
            <span className="shrink-0 rounded bg-zinc-100 px-1.5 py-0.5 text-[10px] tabular-nums text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300">
              {a.counts.open} open / {a.counts.total}
            </span>
          </div>
          <div className="mt-0.5 line-clamp-2 text-[11px] text-zinc-500 dark:text-zinc-400">{a.purpose}</div>
        </div>
      ))}
    </div>
  );
}

// ── <ProjectStatusList items/> ───────────────────────────────────────────────

/** Latest per-project banner assessments with their computed-metric snapshots. */
export function ProjectStatusList({ items }: { items: ProjectStatusItem[] }) {
  if (items.length === 0) return <EmptyNote text="No project assessments yet — run a sweep to generate them." />;
  return (
    <div className="my-2 space-y-2">
      {items.map((p, i) => (
        <div
          key={p.projectId ?? i}
          className="rounded-lg border border-zinc-200 bg-white p-3 dark:border-zinc-700 dark:bg-zinc-900"
        >
          <div className="flex flex-wrap items-center gap-2">
            <SeverityBadge severity={p.severity} />
            <span className="text-sm font-medium text-zinc-900 dark:text-zinc-100">
              {p.projectName ?? p.title}
            </span>
            <span className="text-[10px] text-zinc-400 dark:text-zinc-500">{formatTime(p.updatedAt)}</span>
          </div>
          <div className="mt-1 text-xs leading-relaxed text-zinc-600 dark:text-zinc-300">{p.summary}</div>
          {p.metrics.length > 0 && (
            <div className="mt-2 flex flex-wrap items-center gap-1.5">
              <ComputedTag />
              {p.metrics
                .filter((m) => typeof m.value === "number" || typeof m.value === "string")
                .map((m) => (
                  <span
                    key={m.id}
                    title={`[${m.id}] formula: ${m.formula}`}
                    className="cursor-help rounded bg-zinc-100 px-1.5 py-0.5 text-[10px] tabular-nums text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300"
                  >
                    {m.label}: {String(m.value)}
                  </span>
                ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}

// ── <SweepResult result/> ────────────────────────────────────────────────────

/** Outcome of an on-demand detector sweep. */
export function SweepResult({ result }: { result: SweepResultData }) {
  return (
    <div className="my-2 inline-flex items-center gap-3 rounded-lg border border-zinc-200 bg-white px-3 py-2 text-xs dark:border-zinc-700 dark:bg-zinc-900">
      <svg viewBox="0 0 16 16" className="h-4 w-4 text-emerald-600 dark:text-emerald-400" fill="none" stroke="currentColor" strokeWidth="1.5">
        <circle cx="8" cy="8" r="6.25" />
        <path d="M5.5 8.2l1.8 1.8 3.4-3.6" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <span className="text-zinc-700 dark:text-zinc-200">Sweep complete</span>
      <span className="tabular-nums text-zinc-500 dark:text-zinc-400">
        {result.detected} detected · {result.newFindings} new · {result.published} published
      </span>
    </div>
  );
}

// ── helpers ──────────────────────────────────────────────────────────────────

function EmptyNote({ text }: { text: string }) {
  return (
    <div className="my-2 rounded-lg border border-dashed border-zinc-300 px-3 py-2 text-xs text-zinc-500 dark:border-zinc-700 dark:text-zinc-400">
      {text}
    </div>
  );
}

function formatTime(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleString();
}
