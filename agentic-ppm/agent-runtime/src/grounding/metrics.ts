/**
 * Computed-metrics channel (GROUNDING_AND_HALLUCINATION.md §2 "two-channel output").
 *
 * DETERMINISTIC Cypher aggregates over the graph — no LLM anywhere in this file.
 * Each metric carries a human-readable `formula` describing the Cypher logic, so
 * every number on the console / in a status banner is auditable. The LLM prompt
 * receives these metrics with the instruction to REFERENCE them by id, never to
 * invent numbers; the UI labels this channel "computed, not generated".
 */
import { getGraph } from '../graph/falkor.js';
import { OPEN_STATUSES_EXCLUDED, WORK_LABELS, HIGH_PRIORITIES } from '../agents/detectors.js';

export interface Metric {
  id: string;
  label: string;
  value: number | string | unknown;
  computedAt: string;
  /** Human-readable one-liner of the Cypher logic (auditability). */
  formula: string;
}

export interface PortfolioMetrics {
  computedAt: string;
  metrics: Metric[];
}

export interface ProjectMetrics {
  projectId: string;
  computedAt: string;
  openItems: number;
  overdue: number;
  pctOverdue: number;
  avgProgress: number;
  unassignedHigh: number;
  dueNext7Days: number;
  metrics: Metric[];
}

function today(): string {
  return new Date().toISOString().slice(0, 10);
}

function plusDays(days: number): string {
  return new Date(Date.now() + days * 86_400_000).toISOString().slice(0, 10);
}

function pct(part: number, whole: number): number {
  return whole > 0 ? Math.round((part / whole) * 100) : 0;
}

const OPEN_FILTER = `w.spineClass IN $labels AND NOT coalesce(w.status, 'New') IN $closed`;

/** Portfolio-wide deterministic aggregates. Empty graph → zeros, no errors. */
export async function computePortfolioMetrics(): Promise<PortfolioMetrics> {
  const graph = getGraph();
  const computedAt = new Date().toISOString();
  const params = { labels: WORK_LABELS, closed: OPEN_STATUSES_EXCLUDED, today: today(), high: HIGH_PRIORITIES };

  const [projects, openItems, overdue, unassignedHigh, byProject, assignees, statuses] = await Promise.all([
    graph.query<{ c: number }>(`MATCH (p:Project) RETURN count(p) AS c`),
    graph.query<{ c: number }>(`MATCH (w) WHERE ${OPEN_FILTER} RETURN count(w) AS c`, params),
    graph.query<{ c: number }>(
      `MATCH (w) WHERE ${OPEN_FILTER} AND w.endDate IS NOT NULL AND w.endDate < $today RETURN count(w) AS c`,
      params,
    ),
    graph.query<{ c: number }>(
      `MATCH (w) WHERE ${OPEN_FILTER} AND coalesce(w.priority, 'Normal') IN $high
         AND (w.assignee IS NULL OR w.assignee = '') RETURN count(w) AS c`,
      params,
    ),
    graph.query<{ projectId: string; name: string; avgProgress: number; openItems: number; overdue: number }>(
      `MATCH (p:Project)-[:CONTAINS]->(w) WHERE ${OPEN_FILTER}
       RETURN p.id AS projectId, p.name AS name,
              round(avg(coalesce(w.progress, 0))) AS avgProgress,
              count(w) AS openItems,
              count(CASE WHEN w.endDate IS NOT NULL AND w.endDate < $today THEN 1 END) AS overdue
       ORDER BY openItems DESC LIMIT 25`,
      params,
    ),
    graph.query<{ assignee: string; openCount: number }>(
      `MATCH (w) WHERE ${OPEN_FILTER} AND w.assignee IS NOT NULL AND w.assignee <> ''
       RETURN w.assignee AS assignee, count(w) AS openCount
       ORDER BY openCount DESC LIMIT 10`,
      params,
    ),
    graph.query<{ status: string; c: number }>(
      `MATCH (w) WHERE w.spineClass IN $labels
       RETURN coalesce(w.status, 'New') AS status, count(w) AS c ORDER BY c DESC`,
      params,
    ),
  ]);

  const totalOpen = openItems[0]?.c ?? 0;
  const overdueCount = overdue[0]?.c ?? 0;
  const m = (id: string, label: string, value: Metric['value'], formula: string): Metric => ({
    id, label, value, computedAt, formula,
  });

  return {
    computedAt,
    metrics: [
      m('totalProjects', 'Projects', projects[0]?.c ?? 0, 'count of (:Project) nodes'),
      m('totalOpenItems', 'Open work items', totalOpen, 'count of work items whose status is not Closed/Rejected/Done/Completed/On hold'),
      m('overdueCount', 'Overdue', overdueCount, 'count of open work items with endDate < today'),
      m('overduePct', 'Overdue %', pct(overdueCount, totalOpen), 'overdueCount / totalOpenItems × 100'),
      m('unassignedHighPriorityCount', 'Unassigned high-priority', unassignedHigh[0]?.c ?? 0, 'count of open items with priority in High/Immediate/Urgent/Critical and no assignee'),
      m('avgProgressByProject', 'Avg progress by project', byProject, 'per (:Project)-[:CONTAINS]->(item): avg(progress), count(open), count(open with endDate < today)'),
      m('topLoadedAssignees', 'Top-loaded assignees', assignees, 'per assignee: count of open work items, descending'),
      m('statusDistribution', 'Status distribution', statuses, 'per status: count of work items'),
    ],
  };
}

/** Per-project deterministic aggregates. Empty/unknown project → zeros. */
export async function computeProjectMetrics(projectNodeId: string): Promise<ProjectMetrics> {
  const graph = getGraph();
  const computedAt = new Date().toISOString();
  const params = {
    projectId: projectNodeId,
    closed: OPEN_STATUSES_EXCLUDED,
    today: today(),
    week: plusDays(7),
    high: HIGH_PRIORITIES,
  };

  const rows = await graph.query<{
    openItems: number; overdue: number; avgProgress: number; unassignedHigh: number; dueNext7Days: number;
  }>(
    `MATCH (p:Project { id: $projectId })-[:CONTAINS]->(w)
     WHERE NOT coalesce(w.status, 'New') IN $closed
     RETURN count(w) AS openItems,
            count(CASE WHEN w.endDate IS NOT NULL AND w.endDate < $today THEN 1 END) AS overdue,
            round(avg(coalesce(w.progress, 0))) AS avgProgress,
            count(CASE WHEN coalesce(w.priority, 'Normal') IN $high
                        AND (w.assignee IS NULL OR w.assignee = '') THEN 1 END) AS unassignedHigh,
            count(CASE WHEN w.endDate IS NOT NULL AND w.endDate >= $today AND w.endDate <= $week THEN 1 END) AS dueNext7Days`,
    params,
  );

  const r = rows[0] ?? { openItems: 0, overdue: 0, avgProgress: 0, unassignedHigh: 0, dueNext7Days: 0 };
  const openItems = r.openItems ?? 0;
  const overdue = r.overdue ?? 0;
  const avgProgress = Math.round(r.avgProgress ?? 0);
  const pctOverdue = pct(overdue, openItems);
  const m = (id: string, label: string, value: number, formula: string): Metric => ({
    id, label, value, computedAt, formula,
  });

  return {
    projectId: projectNodeId,
    computedAt,
    openItems,
    overdue,
    pctOverdue,
    avgProgress,
    unassignedHigh: r.unassignedHigh ?? 0,
    dueNext7Days: r.dueNext7Days ?? 0,
    metrics: [
      m('openItems', 'Open items', openItems, 'count of project items whose status is not Closed/Rejected/Done/Completed/On hold'),
      m('overdue', 'Overdue', overdue, 'count of open project items with endDate < today'),
      m('pctOverdue', 'Overdue %', pctOverdue, 'overdue / openItems × 100'),
      m('avgProgress', 'Avg progress', avgProgress, 'avg(progress) over open project items'),
      m('unassignedHigh', 'Unassigned high-priority', r.unassignedHigh ?? 0, 'count of open high-priority project items with no assignee'),
      m('dueNext7Days', 'Due in 7 days', r.dueNext7Days ?? 0, 'count of open project items with today ≤ endDate ≤ today+7d'),
    ],
  };
}

/** Compact one-liner for status banners: visibly the COMPUTED channel. */
export function formatProjectMetricsLine(pm: ProjectMetrics): string {
  return (
    `📊 Computed: ${pm.openItems} open · ${pm.overdue} overdue (${pm.pctOverdue}%) · ` +
    `avg progress ${pm.avgProgress}%` +
    (pm.unassignedHigh ? ` · ${pm.unassignedHigh} unassigned high-priority` : '') +
    (pm.dueNext7Days ? ` · ${pm.dueNext7Days} due in 7 days` : '')
  );
}

/** Render metrics as a prompt block the LLM must reference, not re-derive. */
export function metricsPromptBlock(metrics: Metric[]): string {
  const lines = metrics
    .filter((m) => typeof m.value === 'number' || typeof m.value === 'string')
    .map((m) => `- [${m.id}] ${m.label}: ${m.value} (formula: ${m.formula})`);
  return (
    `COMPUTED METRICS (deterministic, computed from the graph — reference them by id; ` +
    `do NOT invent numbers):\n${lines.join('\n')}`
  );
}
