# frozen_string_literal: true

module Types
  class SprintType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :starts_on, GraphQL::Types::ISO8601Date, null: true
    field :ends_on, GraphQL::Types::ISO8601Date, null: true
  end
end
