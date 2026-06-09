# frozen_string_literal: true

class CreateAgenticPpmAgentRecommendations < ActiveRecord::Migration[7.1]
  def change
    create_table :agentic_ppm_agent_recommendations do |t|
      # Traceability: the ontology subject this finding concerns, e.g.
      # "safe:Feature/123". Resolved back to a record via Ontology#resolve_subject.
      t.string  :ontology_subject, null: false
      t.references :work_package, null: true, foreign_key: true
      t.references :project, null: true, foreign_key: true

      t.string  :agent, null: false              # producing agent, e.g. "RiskAgent"
      t.string  :finding_type                     # e.g. "schedule_risk", "wsjf_reorder"
      t.string  :title, null: false
      t.text    :body                             # human-readable rationale
      t.string  :severity                         # "info" | "warning" | "critical"
      t.float   :confidence                       # 0.0 - 1.0
      t.jsonb   :evidence, null: false, default: {} # graph paths / source refs backing the finding
      t.string  :status, null: false, default: "new"

      t.timestamps
    end

    add_index :agentic_ppm_agent_recommendations, :status
    add_index :agentic_ppm_agent_recommendations, :ontology_subject
  end
end
