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
  module FormConfigurationComponentStreams
    extend ActiveSupport::Concern

    private

    def update_form_configuration_via_turbo_stream(editing_section_key: nil)
      update_sections_via_turbo_stream(editing_section_key:)
      update_inactive_attributes_via_turbo_stream
    end

    def update_sections_via_turbo_stream(editing_section_key: nil, temporary_group: nil, validation_message: nil)
      groups = active_groups_for_turbo_stream
      groups.unshift(temporary_group) if temporary_group.present?

      section_components = groups.map.with_index do |group, index|
        is_editing = editing_section_key.present? && group[:key].to_s == editing_section_key.to_s
        build_section_component(group:, groups:, index:,
                                edit_mode: is_editing,
                                validation_message: (validation_message if is_editing))
      end

      turbo_streams << turbo_stream.update(
        "type-form-configuration-sections-container",
        partial: "work_package_types/form_configuration_tab/sections",
        locals: { section_components: }
      )
    end

    def update_inactive_attributes_via_turbo_stream
      turbo_streams << turbo_stream.replace(
        "type-form-configuration-inactive-container",
        view_context.render(
          WorkPackageTypes::FormConfiguration::InactiveAttributesListComponent.new(
            inactives: form_configuration_groups(@type)[:inactives],
            type: @type
          )
        )
      )
    end

    def replace_section_via_turbo_stream(key:, edit_mode:, validation_message: nil, input_value: nil)
      groups = active_groups_for_turbo_stream
      group = groups.find { |item| item[:key].to_s == key.to_s }
      return if group.nil?

      index = groups.index(group)

      replace_via_turbo_stream(
        component: build_section_component(group:, groups:, index:,
                                           edit_mode:, validation_message:, input_value:)
      )
    end

    def active_groups_for_turbo_stream
      form_configuration_groups(@type)[:actives].reject { |group| group[:key].to_s == "__empty" }
    end

    def build_section_component(group:, groups:, index:, edit_mode:, validation_message: nil, input_value: nil)
      WorkPackageTypes::FormConfiguration::SectionComponent.new(
        group:,
        type: @type,
        ee_available: EnterpriseToken.allows_to?(:edit_attribute_groups),
        first: index.zero?,
        last: index == groups.length - 1,
        edit_mode:,
        validation_message:,
        input_value:
      )
    end

    def render_form_configuration_error(call)
      render_error_flash_message_via_turbo_stream(message: call.errors.full_messages.to_sentence)
    end
  end
end
