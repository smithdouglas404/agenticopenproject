/**
 * Rules engine — wire types.
 *
 * WHAT: The runtime half of a rules engine whose rules are AUTHORED natively in
 * OpenProject (the `agentic_ppm` Rails module). These interfaces mirror the HTTP
 * contract with that module so the loader/evaluator stay type-safe end to end.
 * WHY: Rules are policy, not code — PMs change thresholds in OpenProject and the
 * sidecar evaluates them against the FalkorDB world-model on each sweep/event.
 */

/** Comparison/temporal operators a rule can apply to a resolved metric value. */
export type RuleOperator =
  | 'gt'
  | 'gte'
  | 'lt'
  | 'lte'
  | 'eq'
  | 'ne'
  | 'changed'
  | 'delta_gt'
  | 'delta_lt'
  | 'outside_range'
  | 'crossed_above'
  | 'crossed_below';

export type RuleSeverity = 'info' | 'warning' | 'critical';
export type RuleActionKind = 'alert' | 'recommend' | 'escalate';

/** A single rule as authored in the OpenProject module (rules.json contract). */
export interface Rule {
  id: number;
  /** Scope: null = global, else the OpenProject project this rule applies to. */
  project_id: number | null;
  /** Ontology class the rule targets, e.g. "safe:Epic", "pm:Task", "pm:Project". */
  ontology_class: string;
  /** Metric key, e.g. "percentageDone", "schedule_variance_days", or a custom field. */
  metric: string;
  operator: RuleOperator;
  threshold: number | null;
  /** Upper bound for range/two-sided operators (outside_range). */
  threshold2: number | null;
  severity: RuleSeverity;
  /** Minimum minutes between two firings for the same (rule, node). */
  cooldown_minutes: number;
  action_kind: RuleActionKind;
  notify_openproject: boolean;
  notify_kyndral: boolean;
  enabled: boolean;
}

/** A rule that matched a node — the runtime "finding" before it is published. */
export interface RuleBreach {
  rule: Rule;
  /** Graph node id the breach concerns, e.g. "op-wp-1234" / "op-project-7". */
  nodeId: string;
  ontologyClass: string;
  metric: string;
  observedValue: number | string;
  /** Prior value from RuleState (for delta/changed/crossed operators). */
  previousValue?: number | string;
  threshold?: number;
  threshold2?: number;
  severity: RuleSeverity;
  /** Human-readable explanation, e.g. `Epic "X" percentageDone 35 < threshold 50`. */
  message: string;
}
