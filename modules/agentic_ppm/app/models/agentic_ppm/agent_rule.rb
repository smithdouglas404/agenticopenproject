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
