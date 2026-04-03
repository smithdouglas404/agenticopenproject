# frozen_string_literal: true

module API
  module V3
    module LifecycleStageTransitions
      class LifecycleStageTransitionsByProjectAPI < ::API::OpenProjectAPI
        resources :lifecycle_stage_transitions do
          get do
            transitions = @project.lifecycle_stage_transitions
                                  .includes(:user, :project)
                                  .order(created_at: :desc)

            ::API::V3::LifecycleStageTransitions::LifecycleStageTransitionsCollectionRepresenter
              .new(transitions,
                   self_link: api_v3_paths.project(@project.id) + "/lifecycle_stage_transitions",
                   current_user:)
          end
        end
      end
    end
  end
end
