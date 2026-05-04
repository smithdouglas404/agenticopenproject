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
  module FormConfigurationSections
    class UpdateService < ::WorkPackageTypes::FormConfiguration::BaseService
      def initialize(user:, type:, section_key:)
        super(user:, type:)
        @section_key = section_key
      end

      def perform
        section = find_section(@section_key)
        return failure_with_message(I18n.t("types.edit.form_configuration.not_found")) unless section

        groups = active_groups
        update_result = perform_update(section, groups)
        return update_result if update_result.is_a?(ServiceResult) && update_result.failure?

        persist_groups(groups).tap do |call|
          call.result = section if call.success?
        end
      end

      private

      def perform_update(section, groups)
        return move_section(groups, move_to: params[:move_to], position: params[:position]) if move_requested?
        return update_query(section, params[:query_props]) if params[:query_props].present?

        rename_section!(section, params[:name])
        nil
      end

      def move_section(groups, move_to:, position:)
        current_index = groups.index { |group| group.key.to_s == @section_key.to_s }
        return if current_index.nil?

        new_index = section_move_index(groups:, current_index:, move_to:, position:)

        groups.insert(new_index, groups.delete_at(current_index)) if new_index != current_index
      end

      def rename_section!(section, name)
        stripped_name = name.to_s.strip
        return blank_name_error if stripped_name.blank?

        rename_section(section, stripped_name)
        nil
      end

      def rename_section(section, name)
        if section.internal_key?
          section.display_name = name.presence == default_name_for(section) ? nil : name.presence
        else
          section.key = name
          section.display_name = nil
        end
      end

      def default_name_for(section)
        I18n.t(Type.default_groups[section.key], default: section.key.to_s)
      end

      def move_requested?
        params[:move_to].present? || params[:position].present?
      end

      def update_query(section, query_props)
        query_call = build_query(query_props, name: section.query&.name || "Embedded table: #{@section_key}")
        return query_call if query_call.failure?

        section.attributes = query_call.result
        nil
      end

      def section_move_index(groups:, current_index:, move_to:, position:)
        return (position.to_i - 1).clamp(0, groups.length - 1) if position.present?

        case move_to&.to_sym
        when :highest
          0
        when :higher
          [current_index - 1, 0].max
        when :lower
          [current_index + 1, groups.length - 1].min
        when :lowest
          groups.length - 1
        else
          current_index
        end
      end

      def blank_name_error
        failure_with_message(
          I18n.t("activerecord.errors.models.type.attributes.attribute_groups.group_without_name")
        )
      end
    end
  end
end
