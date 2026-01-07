# frozen_string_literal: true

module Types
  class StoryType < Types::BaseObject
    field :id, ID, null: false
    field :title, String, null: false

    field :backlog, Types::BacklogType, null: false
    field :tasks, [Types::TaskType], null: false

    field :assignee, Types::UserType, null: true
    field :assignee_id, ID, null: true
  end
end
