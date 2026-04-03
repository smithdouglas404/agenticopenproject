# frozen_string_literal: true

class LifecycleStageTransition < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :to_stage, presence: true

  # Map integer values to human-readable stage names
  STAGE_NAMES = Project.defined_enums["lifecycle_stage"].invert.freeze

  def from_stage_name
    STAGE_NAMES[from_stage]
  end

  def to_stage_name
    STAGE_NAMES[to_stage]
  end
end
