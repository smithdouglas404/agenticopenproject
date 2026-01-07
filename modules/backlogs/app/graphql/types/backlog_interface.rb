# frozen_string_literal: true

module Types
  module BacklogInterface
    include Types::BaseInterface

    # field :id, ID, null: false
    field :project_id, ID, null: false
    field :stories, [Types::StoryType], null: false

    definition_methods do
      def resolve_type(object, _context)
        if object.owner_backlog?
          OwnerBacklogType
        else
          SprintBacklogType
        end
      end
    end
  end
end
