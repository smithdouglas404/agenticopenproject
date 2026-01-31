# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++
class MCPConfigurationSeeder < Seeder
  def seed_data!
    seed_server_config if server_missing?

    seed_resource_and_tool_configs
  end

  def applicable?
    server_missing? || tools_missing? || resources_missing?
  end

  def not_applicable_message
    "No seeding of additional MCP configuration necessary."
  end

  private

  def seed_server_config
    MCPConfiguration.create!(
      identifier: API::MCP::CONFIGURATION_IDENTIFIER,
      title: Setting.app_title,
      description: "Performs project management tasks on the given installation of OpenProject.",
      enabled: true
    )
  end

  def seed_resource_and_tool_configs
    (MCPTools.all + MCPResources.all).each do |thing|
      next if MCPConfiguration.find_by(identifier: thing.qualified_name)

      MCPConfiguration.create!(
        identifier: thing.qualified_name,
        title: thing.default_title,
        description: thing.default_description,
        enabled: true
      )
    end
  end

  def server_missing?
    MCPConfiguration.where(identifier: API::MCP::CONFIGURATION_IDENTIFIER).empty?
  end

  def tools_missing?
    (MCPTools.all.map(&:qualified_name) - MCPConfiguration.pluck(:identifier)).any?
  end

  def resources_missing?
    (MCPResources.all.map(&:qualified_name) - MCPConfiguration.pluck(:identifier)).any?
  end
end
