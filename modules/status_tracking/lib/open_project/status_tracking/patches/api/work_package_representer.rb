module OpenProject::StatusTracking
  module Patches
    module API
      module WorkPackageRepresenter
        module_function

        def extension
          ->(*) do
            property :started_at,
                     exec_context: :decorator,
                     getter: ->(*) { represented.started_at&.iso8601 },
                     render_nil: true

            property :done_at,
                     exec_context: :decorator,
                     getter: ->(*) { represented.done_at&.iso8601 },
                     render_nil: true
          end
        end
      end
    end
  end
end
