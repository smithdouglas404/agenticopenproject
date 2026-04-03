# frozen_string_literal: true

module API
  module V3
    module LifecycleStageTransitions
      class LifecycleStageTransitionRepresenter < ::API::Decorators::Single
        include API::Decorators::DateProperty

        property :id

        property :from_stage_name,
                 as: :fromStage

        property :to_stage_name,
                 as: :toStage

        date_time_property :created_at

        resource :project,
                 getter: ->(*) {
                   ::API::V3::Projects::ProjectRepresenter.create(represented.project, current_user:, embed_links: false)
                 },
                 link: ->(*) {
                   {
                     href: api_v3_paths.project(represented.project_id),
                     title: represented.project.name
                   }
                 }

        resource :user,
                 getter: ->(*) {
                   ::API::V3::Users::UserRepresenter.create(represented.user, current_user:)
                 },
                 link: ->(*) {
                   {
                     href: api_v3_paths.user(represented.user_id),
                     title: represented.user.name
                   }
                 }

        def _type
          "LifecycleStageTransition"
        end
      end
    end
  end
end
