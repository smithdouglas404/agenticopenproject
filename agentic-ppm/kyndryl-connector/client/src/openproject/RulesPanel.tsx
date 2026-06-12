/**
 * RulesPanel — a read-only view of the threshold/rules engine for Kyndral-365.
 *
 * Rules are AUTHORED IN OPENPROJECT (the agentic_ppm module is the system of
 * record for rules). This panel only *reads*: it lists the active rules and the
 * recent rule-breach findings so a Kyndral user can see what's being watched and
 * what just tripped — then triage breaches in the ApprovalQueue (same inbox) or
 * over in OpenProject's native inbox. Authoring stays in OpenProject.
 *
 * The loop this sits in (see docs/RULES_ENGINE.md):
 *   author rule in OpenProject → runtime pulls rules.json → evaluates on change
 *   + safety sweep → breach → fan-out to BOTH UIs. THIS PANEL renders the rules
 *   (left/top) and the breaches (right/bottom).
 *
 * Data comes through the server proxy, mirroring
 * server/routes/agentFindings.routes.ts (default /api/agent/*):
 *   GET /api/agent/rules                    → { rules:[...] }  (proxies the
 *        OpenProject /agentic_ppm/api/rules.json, token held server-side)
 *   GET /api/agent/findings?type=RuleBreach → recent breaches (reuses the
 *        existing findings proxy + its `type` filter)
 * NOTE: the /api/agent/rules proxy must be added alongside the findings routes —
 * it does not exist yet; see docs/RULES_ENGINE.md §6.
 *
 * DROP-IN: copy to Kyndral `client/src/openproject/RulesPanel.tsx` and render
 * <RulesPanel /> on the governance / insights page. Tailwind only; no
 * component-library dependency.
 */
import { useCallback, useEffect, useMemo, useState } from "react";

/** A rule row as served by /agentic_ppm/api/rules.json (see RULES_ENGINE.md §4.1). */
export interface AgentRule {
  id: string;
  project_id?: number | null;
  name: string;
  description?: string | null;
  ontology_class: string;
  metric: string;
  operator: string;
  threshold?: number | null;
  threshold2?: number | null;
  severity: "info" | "warning" | "critical" | string;
  enabled: boolean;
  notify_openproject: boolean;
  notify_kyndral: boolean;
  cooldown_minutes?: number | null;
  action_kind?: "alert" | "recommend" | "escalate" | string;
}

/** A rule-breach finding (subset of the agent-runtime finding shape). */
export interface RuleBreachFinding {
  id: string;
  type: string;
  severity: "info" | "warning" | "critical" | "low" | "medium" | "high" | string;
  title: string;
  body?: string;
  projectName?: string;
  workPackageId?: number;
  createdAt: string;
  updatedAt: string;
}

const SEVERITY_STYLES: Record<string, string> = {
  critical: "bg-red-500/10 text-red-600 dark:text-red-300 border-red-500/30",
  high: "bg-red-500/10 text-red-600 dark:text-red-300 border-red-500/30",
  warning: "bg-amber-500/10 text-amber-600 dark:text-amber-300 border-amber-500/30",
  medium: "bg-amber-500/10 text-amber-600 dark:text-amber-300 border-amber-500/30",
  info: "bg-sky-500/10 text-sky-600 dark:text-sky-300 border-sky-500/30",
  low: "bg-sky-500/10 text-sky-600 dark:text-sky-300 border-sky-500/30",
};

/** Human-readable operator label (keep terminology identical to the contract). */
const OPERATOR_LABELS: Record<string, string> = {
  gt: ">",
  gte: "≥",
  lt: "<",
  lte: "≤",
  eq: "=",
  ne: "≠",
  changed: "changed",
  delta_gt: "Δ >",
  delta_lt: "Δ <",
  outside_range: "outside range",
  crossed_above: "crossed above",
  crossed_below: "crossed below",
};

function operatorLabel(op: string): string {
  return OPERATOR_LABELS[op] ?? op;
}

/** Render the threshold portion of a rule (operator-aware). */
function formatThreshold(rule: AgentRule): string {
  const op = operatorLabel(rule.operator);
  if (rule.operator === "changed") return op;
  if (rule.operator === "outside_range") {
    return `${op} [${rule.threshold ?? "?"}, ${rule.threshold2 ?? "?"}]`;
  }
  return `${op} ${rule.threshold ?? "?"}`;
}

function sevClass(severity: string): string {
  return SEVERITY_STYLES[severity] ?? SEVERITY_STYLES.info;
}

/** "3m ago" / "2h ago" / "5d ago" for breach timestamps. */
function relativeTime(value: string): string {
  const date = new Date(value);
  const ms = Date.now() - date.getTime();
  if (Number.isNaN(ms)) return "";
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

export interface RulesPanelProps {
  /** Base of the server proxy routes (mirrors ApprovalQueue). */
  apiBase?: string;
  /** Optional deep link to the OpenProject rules authoring UI. */
  openProjectRulesUrl?: string;
  className?: string;
}

export function RulesPanel({
  apiBase = "/api/agent",
  openProjectRulesUrl,
  className = "",
}: RulesPanelProps) {
  const [rules, setRules] = useState<AgentRule[]>([]);
  const [breaches, setBreaches] = useState<RuleBreachFinding[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [rulesRes, breachRes] = await Promise.all([
        fetch(`${apiBase}/rules`),
        fetch(`${apiBase}/findings?type=RuleBreach`).catch(() => null),
      ]);
      if (!rulesRes.ok) throw new Error(`rules: HTTP ${rulesRes.status}`);
      const rulesData = await rulesRes.json();
      setRules(Array.isArray(rulesData) ? rulesData : (rulesData.rules ?? []));
      if (breachRes?.ok) {
        const breachData = await breachRes.json();
        setBreaches(Array.isArray(breachData) ? breachData : (breachData.findings ?? []));
      } else {
        setBreaches([]);
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

  const sortedRules = useMemo(() => {
    const rank: Record<string, number> = { critical: 0, warning: 1, info: 2 };
    return [...rules].sort(
      (a, b) =>
        Number(b.enabled) - Number(a.enabled) ||
        (rank[a.severity] ?? 3) - (rank[b.severity] ?? 3) ||
        a.name.localeCompare(b.name),
    );
  }, [rules]);

  const sortedBreaches = useMemo(
    () => [...breaches].sort((a, b) => b.updatedAt.localeCompare(a.updatedAt)),
    [breaches],
  );

  return (
    <div className={`flex flex-col gap-3 ${className}`}>
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-base font-semibold">Threshold rules</h2>
          <p className="text-xs text-neutral-500 dark:text-neutral-400">
            Authored in OpenProject · evaluated by the runtime on change + safety sweep ·
            breaches appear in both UIs.{" "}
            {openProjectRulesUrl ? (
              <a
                href={openProjectRulesUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="text-sky-600 underline hover:text-sky-700 dark:text-sky-300"
              >
                Author rules in OpenProject →
              </a>
            ) : (
              <span className="text-neutral-400">Author rules in OpenProject.</span>
            )}
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
      {loading && <div className="text-sm text-neutral-500">Loading rules…</div>}

      {/* Active rules (read-only) */}
      {!loading && sortedRules.length === 0 && !error && (
        <div className="rounded-md border border-neutral-200 px-3 py-6 text-center text-sm text-neutral-500 dark:border-neutral-800">
          No rules defined yet. Add thresholds in OpenProject (agentic_ppm → Rules).
        </div>
      )}

      <div className="flex flex-col gap-2">
        {sortedRules.map((rule) => (
          <div
            key={rule.id}
            className={`rounded-lg border p-3 ${
              rule.enabled
                ? "border-neutral-200 dark:border-neutral-800"
                : "border-neutral-200 opacity-60 dark:border-neutral-800"
            }`}
          >
            <div className="flex flex-wrap items-center gap-2">
              <span className={`rounded-full border px-2 py-0.5 text-[11px] font-medium ${sevClass(rule.severity)}`}>
                {rule.severity}
              </span>
              <span className="font-mono text-[11px] text-neutral-600 dark:text-neutral-300">
                {rule.ontology_class}
              </span>
              <span className="text-[11px] text-neutral-400">·</span>
              <span className="font-mono text-[11px] text-neutral-600 dark:text-neutral-300">
                {rule.metric}
              </span>
              <span className="font-mono text-[11px] text-neutral-500">{formatThreshold(rule)}</span>
              {!rule.enabled && (
                <span className="rounded-full bg-neutral-500/10 px-2 py-0.5 text-[11px] text-neutral-500">
                  disabled
                </span>
              )}
              {rule.notify_openproject && (
                <span
                  className="rounded-full bg-indigo-500/10 px-2 py-0.5 text-[11px] text-indigo-600 dark:text-indigo-300"
                  title="Breaches notify OpenProject (Agent Alert WP + comment + banner)"
                >
                  OP
                </span>
              )}
              {rule.notify_kyndral && (
                <span
                  className="rounded-full bg-teal-500/10 px-2 py-0.5 text-[11px] text-teal-600 dark:text-teal-300"
                  title="Breaches notify Kyndral (ApprovalQueue + AI-SDK)"
                >
                  Kyndral
                </span>
              )}
              {rule.action_kind && (
                <span className="ml-auto rounded-full bg-neutral-500/10 px-2 py-0.5 text-[11px] text-neutral-500">
                  {rule.action_kind}
                </span>
              )}
            </div>
            <h3 className="mt-2 text-sm font-semibold">{rule.name}</h3>
            {rule.description && (
              <p className="mt-0.5 text-xs text-neutral-600 dark:text-neutral-400">{rule.description}</p>
            )}
            <p className="mt-1 text-[10px] uppercase tracking-wide text-neutral-400">
              {rule.project_id == null ? "Global rule" : `Project ${rule.project_id}`}
              {typeof rule.cooldown_minutes === "number" && rule.cooldown_minutes > 0
                ? ` · cooldown ${rule.cooldown_minutes}m`
                : ""}
              {" · authored in OpenProject"}
            </p>
          </div>
        ))}
      </div>

      {/* Recent breaches (reuses the findings proxy) */}
      <div className="mt-2">
        <h3 className="text-sm font-semibold">Recent rule breaches</h3>
        <p className="text-[11px] text-neutral-500 dark:text-neutral-400">
          Triage these in the Approval Queue or in OpenProject's inbox — both show the same breach.
        </p>
        {!loading && sortedBreaches.length === 0 && !error && (
          <div className="mt-2 rounded-md border border-neutral-200 px-3 py-4 text-center text-xs text-neutral-500 dark:border-neutral-800">
            No rule breaches. Nothing has crossed a threshold — or the next sweep hasn't run yet.
          </div>
        )}
        <ul className="mt-2 flex flex-col gap-1.5">
          {sortedBreaches.map((breach) => (
            <li
              key={breach.id}
              className="flex items-center gap-2 rounded-md border border-neutral-200 px-3 py-2 dark:border-neutral-800"
            >
              <span className={`rounded-full border px-2 py-0.5 text-[10px] font-medium ${sevClass(breach.severity)}`}>
                {breach.severity}
              </span>
              <span className="flex-1 truncate text-xs text-neutral-700 dark:text-neutral-300">
                {breach.title}
                {breach.projectName ? (
                  <span className="text-neutral-400"> · {breach.projectName}</span>
                ) : null}
              </span>
              <span className="shrink-0 text-[10px] text-neutral-400">{relativeTime(breach.updatedAt)}</span>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

export default RulesPanel;
