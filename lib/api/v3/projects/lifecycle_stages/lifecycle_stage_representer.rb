# frozen_string_literal: true

module API
  module V3
    module Projects
      module LifecycleStages
        class LifecycleStageRepresenter < ::API::Decorators::Single
          link :self do
            {
              href: api_v3_paths.project_lifecycle_stage(represented),
              title: I18n.t(:"activerecord.attributes.project.lifecycle_stages.#{represented}",
                            default: represented.to_s.humanize)
            }
          end

          property :id,
                   getter: ->(*) { self }

          property :name,
                   getter: ->(*) {
                     I18n.t(:"activerecord.attributes.project.lifecycle_stages.#{self}",
                            default: to_s.humanize)
                   }

          def _type
            "ProjectLifecycleStage"
          end
        end
      end
    end
  end
end
