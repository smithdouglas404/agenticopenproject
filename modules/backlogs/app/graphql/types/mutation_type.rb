# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :upsert_task, mutation: Mutations::UpsertTask
  end
end
