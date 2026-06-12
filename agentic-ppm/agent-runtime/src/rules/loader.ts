/**
 * Rules loader + metric resolution.
 *
 * WHAT: Loads Rule[] either from the OpenProject module endpoint (cached with a
 * TTL) or from a local JSON file / inline env, and exposes METRIC_RESOLVERS that
 * turn a rule's `metric` key into a concrete value for a given graph node.
 * WHY: The evaluator must never throw into the sweep — a flaky rules endpoint or
 * an unresolvable metric degrades to "use last cache" / "skip this node", never a
 * crash. Metric resolution is centralized here so direct props and COMPUTED
 * metrics (reusing src/grounding/metrics.ts) share one mapping.
 */
import { readFile } from 'node:fs/promises';
import { config } from '../config.js';
import type { Rule } from './types.js';
import { getRulesJson } from './opModuleClient.js';
import { computeProjectMetrics } from '../grounding/metrics.js';

// ---------------------------------------------------------------------------
// Loading + caching
// ---------------------------------------------------------------------------

let cache: { rules: Rule[]; at: number } | null = null;

/** Drop the in-memory cache so the next loadRules() re-fetches. */
export function invalidateRulesCache(): void {
  cache = null;
}

/** Coerce a parsed JSON blob ({rules:[...]} or a bare array) into Rule[]. */
function asRules(parsed: unknown): Rule[] {
  if (Array.isArray(parsed)) return parsed as Rule[];
  if (parsed && typeof parsed === 'object' && Array.isArray((parsed as { rules?: unknown }).rules)) {
    return (parsed as { rules: Rule[] }).rules;
  }
  return [];
}

async function loadLocalRules(): Promise<Rule[]> {
  if (config.rules.localFile) {
    const raw = await readFile(config.rules.localFile, 'utf8');
    return asRules(JSON.parse(raw));
  }
  if (process.env.RULES_JSON) {
    return asRules(JSON.parse(process.env.RULES_JSON));
  }
  console.warn('[rules] source=local but neither RULES_LOCAL_FILE nor RULES_JSON is set');
  return [];
}

/**
 * Load the active (enabled) rules. Cached in-memory for refreshMinutes when the
 * source is the OpenProject endpoint; on a fetch failure returns the last cache
 * (or []) and warns — NEVER throws into the sweep.
 */
export async function loadRules(): Promise<Rule[]> {
  if (config.rules.source === 'local') {
    try {
      return (await loadLocalRules()).filter((r) => r.enabled);
    } catch (err) {
      console.warn(`[rules] local load failed: ${(err as Error).message}`);
      return [];
    }
  }

  // source === 'openproject': serve from cache while fresh.
  const ttlMs = Math.max(0, config.rules.refreshMinutes) * 60_000;
  if (cache && Date.now() - cache.at < ttlMs) return cache.rules;

  try {
    const rules = (await getRulesJson()).filter((r) => r.enabled);
    cache = { rules, at: Date.now() };
    return rules;
  } catch (err) {
    console.warn(`[rules] endpoint unreachable, using ${cache ? 'last cache' : 'empty set'}: ${(err as Error).message}`);
    return cache?.rules ?? [];
  }
}

// ---------------------------------------------------------------------------
// Metric resolution
// ---------------------------------------------------------------------------

/** A node as resolved from the graph: id + its scalar properties. */
export interface ResolvedNode {
  id: string;
  props: Record<string, unknown>;
}

/**
 * A metric resolver returns the metric's value for a node, or undefined when it
 * cannot be resolved (rule is then skipped for that node, with a debug log).
 * COMPUTED metrics may be async (they aggregate over the graph).
 */
export type MetricResolver = (node: ResolvedNode) => number | string | undefined | Promise<number | string | undefined>;

/** Read a numeric-ish prop, tolerating string-encoded numbers from the graph. */
function num(value: unknown): number | undefined {
  if (typeof value === 'number') return value;
  if (typeof value === 'string' && value.trim() !== '' && !Number.isNaN(Number(value))) return Number(value);
  return undefined;
}

/** Cache project-metric computations within a single evaluation pass (by node id). */
const projectMetricsCache = new Map<string, Awaited<ReturnType<typeof computeProjectMetrics>>>();
async function projectMetrics(nodeId: string) {
  let pm = projectMetricsCache.get(nodeId);
  if (!pm) {
    pm = await computeProjectMetrics(nodeId);
    projectMetricsCache.set(nodeId, pm);
  }
  return pm;
}

/** Clear the per-pass project-metrics cache (called at the start of evaluateRules). */
export function resetMetricCaches(): void {
  projectMetricsCache.clear();
}

/**
 * Map metric keys to resolvers. Direct node props are cheap; COMPUTED metrics
 * reuse computeProjectMetrics for project-scoped aggregates (schedule/overdue).
 * A metric absent from this map and from node props is treated as a custom field
 * lookup against the node's own properties (best effort).
 */
export const METRIC_RESOLVERS: Record<string, MetricResolver> = {
  // --- direct work-item / project props -----------------------------------
  percentageDone: (n) => num(n.props.progress),
  progress: (n) => num(n.props.progress),
  status: (n) => (n.props.status == null ? undefined : String(n.props.status)),
  priority: (n) => (n.props.priority == null ? undefined : String(n.props.priority)),
  spentHours: (n) => num(n.props.spentHours),
  estimatedHours: (n) => num(n.props.estimatedHours),
  risk_score: (n) => num(n.props.riskScore ?? n.props.risk_score),

  // --- COMPUTED, project-scoped (reuse grounding/metrics.ts) ---------------
  schedule_variance_days: async (n) => {
    // Proxy: count of overdue open items in the project (no baseline dates in graph).
    const pm = await projectMetrics(n.id);
    return pm.overdue;
  },
  overduePct: async (n) => {
    const pm = await projectMetrics(n.id);
    return pm.pctOverdue;
  },
  avgProgress: async (n) => {
    const pm = await projectMetrics(n.id);
    return pm.avgProgress;
  },
  openItems: async (n) => {
    const pm = await projectMetrics(n.id);
    return pm.openItems;
  },
  unassignedHigh: async (n) => {
    const pm = await projectMetrics(n.id);
    return pm.unassignedHigh;
  },
};

/**
 * Resolve a rule's metric value for a node. Returns undefined when unresolvable,
 * after trying: (1) a named resolver, (2) the budget_variance proxy, (3) a direct
 * property of that exact name (custom-field key fallback).
 */
export async function resolveMetric(metric: string, node: ResolvedNode): Promise<number | string | undefined> {
  const resolver = METRIC_RESOLVERS[metric];
  if (resolver) return resolver(node);

  // budget_variance: spent − estimate when both present (CostAnomaly proxy).
  if (metric === 'budget_variance') {
    const spent = num(node.props.spentHours);
    const est = num(node.props.estimatedHours);
    if (spent != null && est != null) return spent - est;
    return undefined;
  }

  // Custom-field fallback: a prop with this exact key on the node.
  if (metric in node.props) {
    const raw = node.props[metric];
    if (raw == null) return undefined;
    return num(raw) ?? String(raw);
  }
  return undefined;
}
