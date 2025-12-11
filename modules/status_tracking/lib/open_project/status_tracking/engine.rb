require "open_project/plugins"
require_relative "patches/api/work_package_representer"

module OpenProject::StatusTracking
  class Engine < ::Rails::Engine
    engine_name :openproject_status_tracking

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-status_tracking",
             author_url: "https://www.openproject.org",
             bundled: true do
      project_module(:status_tracking) do
        permission(:view_status_tracking,
                   {},
                   permissible_on: %i[project work_package])
      end
    end

    patches %w[WorkPackage]

    extend_api_response(:v3, :work_packages, :work_package,
                        &::OpenProject::StatusTracking::Patches::API::WorkPackageRepresenter.extension)

    extend_api_response(:v3, :work_packages, :work_package_payload,
                        &::OpenProject::StatusTracking::Patches::API::WorkPackageRepresenter.extension)
  end
end
