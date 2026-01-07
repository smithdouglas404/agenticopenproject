# frozen_string_literal: true

module Types
  class SprintBacklogType < Types::BaseObject
    implements Types::BacklogInterface

    field :sprint, Types::SprintType, null: false
    field :sprint_id, ID, null: false
  end
end
