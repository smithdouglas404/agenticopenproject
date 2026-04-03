# frozen_string_literal: true

module API
  module V3
    module Projects
      module LifecycleStages
        class LifecycleStagesAPI < ::API::OpenProjectAPI
          resources :project_lifecycle_stages do
            params do
              requires :id, desc: "Project lifecycle stage identifier"
            end
            route_param :id do
              helpers do
                def lifecycle_stage_exists?
                  ::Project.lifecycle_stages.keys.include?(params[:id])
                end
              end

              after_validation do
                raise API::Errors::NotFound unless lifecycle_stage_exists?
              end

              get do
                API::V3::Projects::LifecycleStages::LifecycleStageRepresenter
                  .new(params[:id], current_user:, embed_links: true)
              end
            end
          end
        end
      end
    end
  end
end
