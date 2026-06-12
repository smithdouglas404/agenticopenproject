# frozen_string_literal: true

module AgenticPpm
  # The *authoring* side of the rules/thresholds system: a human-declared
  # condition ("alert me when an Epic's percentageDone drops below 40") that
  # the TypeScript agent runtime pulls and *evaluates* against the knowledge
  # graph. This model never evaluates anything itself -- it only persists the
  # rule definition. When the runtime detects a breach it POSTs back an
  # AgentRecommendation (finding_type "rule_breach") via the alerts API.
  #
  # A rule with a nil project_id is global and applies to every project; a
  # project-scoped rule only applies within its project.
  class AgentRule < ApplicationRecord
    self.table_name = "agentic_ppm_agent_rules"

    belongs_to :project, optional: true

    OPERATORS = %w[
      gt gte lt lte eq ne changed
      delta_gt delta_lt outside_range crossed_above crossed_below
    ].freeze

    # Operators that compare against an observed value but need no threshold.
    THRESHOLDLESS_OPERATORS = %w[changed].freeze

    SEVERITIES = %w[info warning critical].freeze

    # ---- Friendly authoring options ---------------------------------------
    # Non-technical users must never type a raw ontology IRI ("safe:Epic") or
    # an internal metric key ("percentageDone"). These curated [label, value]
    # lists drive the form dropdowns; the value is the canonical token the
    # agent-runtime resolves (see src/ontology/spine.ts + src/rules/loader.ts
    # METRIC_RESOLVERS). Extend these as the ontology/metrics grow.

    ONTOLOGY_CLASS_OPTIONS = [
      ["Epic", "safe:Epic"],
      ["Feature", "safe:Feature"],
      ["User story", "safe:Story"],
      ["Task", "pm:Task"],
      ["Milestone", "pm:Milestone"],
      ["Risk", "pm:Risk"],
      ["Project (whole project)", "pm:Project"]
    ].freeze

    # Metrics that apply to a single work item (Epic/Feature/Story/Task).
    WORK_ITEM_METRIC_OPTIONS = [
      ["Percent complete (%)", "percentageDone"],
      ["Budget variance (spent − estimated, hours)", "budget_variance"],
      ["Risk score", "risk_score"]
    ].freeze

    # Metrics computed across a whole project.
    PROJECT_METRIC_OPTIONS = [
      ["Overdue open items (%)", "pctOverdue"],
      ["Average progress (%)", "avgProgress"],
      ["Open items (count)", "openItems"],
      ["Schedule slippage (days)", "schedule_variance_days"]
    ].freeze

    # Operators in plain English, ordered most-common first. label => value.
    OPERATOR_OPTIONS = [
      ["is below", "lt"],
      ["is at or below", "lte"],
      ["is above", "gt"],
      ["is at or above", "gte"],
      ["drops below (crosses down)", "crossed_below"],
      ["rises above (crosses up)", "crossed_above"],
      ["changes at all", "changed"],
      ["changes by more than", "delta_gt"],
      ["equals", "eq"],
      ["does not equal", "ne"],
      ["is outside the range", "outside_range"]
    ].freeze

    # A ready-to-edit decision graph so the "Advanced" box is never blank/scary:
    # "if percent complete < 50 => critical breach; < 70 => warning".
    STARTER_JDM = {
      "nodes" => [
        { "id" => "in", "type" => "inputNode", "name" => "request",
          "position" => { "x" => 0, "y" => 0 } },
        { "id" => "dt", "type" => "decisionTableNode", "name" => "health",
          "position" => { "x" => 250, "y" => 0 },
          "content" => {
            "hitPolicy" => "first",
            "inputs" => [{ "id" => "i1", "field" => "percentageDone", "name" => "Progress" }],
            "outputs" => [
              { "id" => "o1", "field" => "breach", "name" => "Breach" },
              { "id" => "o2", "field" => "severity", "name" => "Severity" }
            ],
            "rules" => [
              { "_id" => "r1", "i1" => "< 50", "o1" => "true", "o2" => "\"critical\"" },
              { "_id" => "r2", "i1" => "< 70", "o1" => "true", "o2" => "\"warning\"" },
              { "_id" => "r3", "i1" => "", "o1" => "false", "o2" => "\"ok\"" }
            ]
          } },
        { "id" => "out", "type" => "outputNode", "name" => "response",
          "position" => { "x" => 500, "y" => 0 } }
      ],
      "edges" => [
        { "id" => "e1", "sourceId" => "in", "targetId" => "dt" },
        { "id" => "e2", "sourceId" => "dt", "targetId" => "out" }
      ]
    }.freeze
    # -----------------------------------------------------------------------

    enum :severity, {
      info: "info",
      warning: "warning",
      critical: "critical"
    }, prefix: true, default: "warning"

    # A "threshold" rule is the original simple comparison; a "decision" rule
    # carries a GoRules JDM graph in :jdm, evaluated by the runtime's ZEN engine.
    enum :kind, {
      threshold: "threshold",
      decision: "decision"
    }, prefix: true, default: "threshold"

    enum :operator, OPERATORS.index_with(&:itself), prefix: true

    validates :name, :ontology_class, presence: true
    # The metric/operator/threshold trio only governs threshold rules; a
    # decision rule legitimately has none of them (its logic lives in :jdm).
    validates :metric, :operator, presence: true, if: :kind_threshold?
    validates :threshold, presence: true,
                          if: -> { kind_threshold? && !THRESHOLDLESS_OPERATORS.include?(operator) }
    validates :severity, inclusion: { in: SEVERITIES }
    validate :jdm_shape

    # The form pre-fills the decision-graph box with a starter so it is never
    # blank; a threshold rule should not actually persist it. Reset to {} so
    # only real decision rules carry a graph.
    before_validation :reset_jdm_for_threshold

    scope :enabled, -> { where(enabled: true) }
    scope :global, -> { where(project_id: nil) }
    scope :for_class, ->(klass) { where(ontology_class: klass) }

    # The hash the agent-runtime consumes when it pulls rules to evaluate.
    # Keep this shape stable -- it is the contract the runtime depends on.
    # For decision rules we emit the GoRules JDM graph; threshold rules emit
    # an empty {} (the runtime treats absent/empty jdm as "no decision").
    def to_runtime_json
      {
        id:,
        project_id:,
        kind:,
        ontology_class:,
        metric:,
        operator:,
        threshold:,
        threshold2:,
        severity:,
        cooldown_minutes:,
        action_kind:,
        notify_openproject:,
        notify_kyndral:,
        enabled:,
        jdm: kind_decision? ? jdm : {}
      }
    end

    private

    # Threshold rules don't use a decision graph; drop the starter the form
    # pre-fills so the stored row stays clean and to_runtime_json emits {}.
    def reset_jdm_for_threshold
      self.jdm = {} if kind_threshold?
    end

    # A decision rule must carry something that looks like a GoRules JDM: a
    # Hash with a "nodes" key (string- or symbol-keyed). Threshold rules are
    # exempt -- they have no JDM.
    def jdm_shape
      return if kind_threshold?
      return if jdm.is_a?(Hash) && (jdm["nodes"] || jdm[:nodes])

      errors.add(:jdm, :invalid)
    end
  end
end
