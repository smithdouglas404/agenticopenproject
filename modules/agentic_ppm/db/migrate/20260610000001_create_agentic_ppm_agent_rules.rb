# frozen_string_literal: true

class CreateAgenticPpmAgentRules < ActiveRecord::Migration[7.1]
  def change
    create_table :agentic_ppm_agent_rules do |t|
      # null project_id => a global rule that applies across every project.
      t.references :project, null: true, foreign_key: true
      t.string  :name, null: false
      t.text    :description

      # Which ontology elements this rule scans, e.g. "safe:Epic", "pm:Task".
      t.string  :ontology_class, null: false
      # The field/metric to test, e.g. "percentageDone", "budget_variance",
      # "schedule_variance_days", "risk_score", or "customField12".
      t.string  :metric, null: false
      # gt|gte|lt|lte|eq|ne|changed|delta_gt|delta_lt|outside_range|
      # crossed_above|crossed_below
      t.string  :operator, null: false

      t.float   :threshold                          # primary comparison value
      t.float   :threshold2, null: true             # upper bound (outside_range / delta)

      t.string  :severity, null: false, default: "warning" # info|warning|critical
      t.boolean :enabled, null: false, default: true

      t.boolean :notify_openproject, default: true
      t.boolean :notify_kyndral, default: true

      # Minimum gap before the same rule+entity re-alerts.
      t.integer :cooldown_minutes, default: 60
      t.string  :action_kind, default: "alert"      # alert|recommend|escalate

      t.datetime :last_evaluated_at, null: true

      t.timestamps
    end

    # t.references :project already adds an index on :project_id.
    add_index :agentic_ppm_agent_rules, :enabled
    add_index :agentic_ppm_agent_rules, :ontology_class
  end
end
