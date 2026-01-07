# frozen_string_literal: true

class BacklogsSchema < GraphQL::Schema
  mutation(Types::MutationType)
  # query(Types::QueryType)

  orphan_types Types::SprintBacklogType, Types::OwnerBacklogType
end
