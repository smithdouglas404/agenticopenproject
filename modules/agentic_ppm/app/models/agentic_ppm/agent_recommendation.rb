# frozen_string_literal: true

module AgenticPpm
  # The persisted form of a k360:AgentFinding / k360:Intervention: a
  # recommendation an agent produced from reasoning over the knowledge graph,
  # surfaced in the Insights inbox for a human to accept, dismiss or apply.
  #
  # OpenProject remains the system of record; this table stores the *insight*
  # layer (operational, agent-authored) with a traceable link back to the
  # work package / project it concerns via an ontology subject IRI.
  class AgentRecommendation < ApplicationRecord
    self.table_name = "agentic_ppm_agent_recommendations"

    belongs_to :work_package, optional: true
    belongs_to :project, optional: true

    # Lifecycle of a recommendation as a human triages it (HITL).
    enum :status, {
      new: "new",
      accepted: "accepted",
      dismissed: "dismissed",
      applied: "applied"
    }, prefix: true, default: "new"

    validates :agent, :title, :ontology_subject, presence: true
    validates :confidence,
              numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 },
              allow_nil: true

    scope :open, -> { where(status: "new") }
  end
end
