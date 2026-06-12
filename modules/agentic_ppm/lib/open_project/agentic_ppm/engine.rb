# frozen_string_literal: true

# OpenProject Agentic PPM module
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

require "open_project/plugins"
require "open_project/agentic_ppm/ontology"

module OpenProject::AgenticPpm
  class Engine < ::Rails::Engine
    engine_name :openproject_agentic_ppm

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-agentic_ppm",
             author_url: "https://github.com/smithdouglas404/agenticopenproject",
             bundled: true,
             settings: { default: { "graph_endpoint" => nil, "rules_api_token" => nil } } do
      project_module :agentic_ppm, order: 90 do
        permission :view_agent_recommendations,
                   { "agentic_ppm/recommendations": %i[index show] },
                   permissible_on: :project,
                   dependencies: :view_work_packages
        permission :manage_agent_recommendations,
                   { "agentic_ppm/recommendations": %i[index show update] },
                   permissible_on: :project,
                   dependencies: :view_work_packages
        permission :view_agent_rules,
                   { "agentic_ppm/rules": %i[index] },
                   permissible_on: :project,
                   dependencies: :view_work_packages
        permission :manage_agent_rules,
                   { "agentic_ppm/rules": %i[index new create edit update destroy] },
                   permissible_on: :project,
                   dependencies: :view_work_packages
      end

      menu :project_menu,
           :agentic_ppm,
           { controller: "/agentic_ppm/recommendations", action: :index },
           caption: :"agentic_ppm.label_insights",
           after: :work_packages,
           icon: "op-view-list"

      menu :project_menu,
           :agentic_ppm_rules,
           { controller: "/agentic_ppm/rules", action: :index },
           caption: :"agentic_ppm.label_rules",
           after: :agentic_ppm,
           icon: "op-view-list"
    end

    # Build the ontology <-> OpenProject binding registry on every reload so
    # the projector and the reverse resolver always see the current mapping.
    config.to_prepare do
      OpenProject::AgenticPpm::Ontology.register!
    end
  end
end
