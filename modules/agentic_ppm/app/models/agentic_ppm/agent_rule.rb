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

    enum :operator, OPERATORS.index_with(&:itself), prefix: true

    validates :name, :ontology_class, :metric, :operator, presence: true
    validates :threshold, presence: true, unless: -> { THRESHOLDLESS_OPERATORS.include?(operator) }
    validates :severity, inclusion: { in: SEVERITIES }

    scope :enabled, -> { where(enabled: true) }
    scope :global, -> { where(project_id: nil) }
    scope :for_class, ->(klass) { where(ontology_class: klass) }

    # The hash the agent-runtime consumes when it pulls rules to evaluate.
    # Keep this shape stable -- it is the contract the runtime depends on.
    def to_runtime_json
      {
        id:,
        project_id:,
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
        enabled:
      }
    end
  end
end
