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

/**
 * Rule core kind:
 *   - 'threshold' (default when absent): the existing operator/threshold path — a
 *     single metric is resolved per node and compared with an operator.
 *   - 'decision': a GoRules JDM graph (`jdm`) is evaluated against the node's
 *     decision context (see decisionContext.ts) and returns a DecisionOutput.
 */
export type RuleKind = 'threshold' | 'decision';

/** A single rule as authored in the OpenProject module (rules.json contract). */
export interface Rule {
  id: number;
  /** Scope: null = global, else the OpenProject project this rule applies to. */
  project_id: number | null;
  /** Ontology class the rule targets, e.g. "safe:Epic", "pm:Task", "pm:Project". */
  ontology_class: string;
  /**
   * Which decision core evaluates this rule. Absent ⇒ 'threshold' (backward
   * compatible). When 'decision', `jdm` MUST be present and operator/threshold
   * may be omitted.
   */
  kind?: RuleKind;
  /**
   * GoRules JDM graph object ({ nodes, edges, ... }) evaluated by the ZEN engine
   * when kind === 'decision'. Passed to ZenEngine.createDecision as a JS OBJECT.
   * Typed `unknown` here so the wire contract stays loose; zenEvaluator narrows it.
   */
  jdm?: unknown;
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

/**
 * OUTPUT CONTRACT — the shape a kind:'decision' JDM is expected to RETURN from
 * `decision.evaluate(ctx).result`. JDM authors target exactly these fields:
 *   - breach:      REQUIRED boolean. true ⇒ produce a RuleBreach; false ⇒ no-op.
 *   - severity:    optional; falls back to the rule's own `severity`.
 *   - message:     optional human-readable explanation; a default is generated.
 *   - action_kind: optional hint mirroring RuleActionKind (alert/recommend/escalate).
 *   - metric:      optional metric key naming what the decision keyed on (used to
 *                  resolve observedValue from the context when `value` is absent).
 *   - value:       optional observed value (number or string) for the breach.
 * A JDM with hitPolicy 'collect' may instead return an ARRAY of DecisionOutput
 * (one breach per truthy element) — both forms are accepted by the evaluator.
 */
export interface DecisionOutput {
  breach: boolean;
  severity?: RuleSeverity;
  message?: string;
  action_kind?: string;
  metric?: string;
  value?: number | string;
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
