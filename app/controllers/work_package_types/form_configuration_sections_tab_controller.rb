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

module WorkPackageTypes
  class FormConfigurationSectionsTabController < BaseTabController
    include TypesHelper

    def edit
      group = find_active_group(params[:key])
      return head :not_found unless group

      render_section_component(group:, edit_mode: true)
    end

    def cancel_rename
      group = find_active_group(params[:key])
      return head :not_found unless group

      render_section_component(group:, edit_mode: false)
    end

    private

    def find_active_group(key)
      actives = form_configuration_groups(@type)[:actives]
      actives.find { |g| g[:key].to_s == key.to_s }
    end

    def render_section_component(group:, edit_mode:)
      form_attrs = form_configuration_groups(@type)
      actives = form_attrs[:actives].reject { |g| g[:key].to_s == "__empty" }
      idx = actives.index { |g| g[:key].to_s == group[:key].to_s }

      component = WorkPackageTypes::FormConfiguration::SectionComponent.new(
        group:,
        type: @type,
        first: idx == 0,
        last: idx == actives.length - 1,
        edit_mode:
      )

      render turbo_stream: component.render_as_turbo_stream(view_context:, action: :replace)
    end
  end
end
