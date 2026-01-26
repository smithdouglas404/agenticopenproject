# frozen_string_literal: true

module Types
  class ProjectType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false

    field :backlogs, [BacklogInterface], null: false

    def backlogs
      owner_backlogs = Backlog.owner_backlogs(@object)
      sprint_backlogs = Backlog.sprint_backlogs(@object)

      owner_backlogs + sprint_backlogs
    end
  end
end
