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
  module FormConfigurationRows
    class UpdateService < ::WorkPackageTypes::FormConfiguration::BaseService
      INACTIVE_TARGET = "inactive"

      def initialize(user:, type:, row_key:)
        super(user:, type:)
        @row_key = row_key
      end

      def perform
        move_to = params[:move_to]
        target_id = params[:target_id]
        position = params[:position]
        
        if move_to.present?
          move_row(move_to.to_sym)
        elsif target_id.present?
          drop_row(target_id:, position:)
        else
          failure_with_message(I18n.t("types.edit.form_configuration.not_found"))
        end
      end

      private

      def move_row(move_to)
        row = find_row(@row_key)
        unless row
          return failure_with_message(not_found_message(action: :move, move_to:))
        end

        attributes = row[:group].attributes.dup
        current_index = row[:index]
        new_index = case move_to
                    when :highest
                      0
                    when :higher
                      [current_index - 1, 0].max
                    when :lower
                      [current_index + 1, attributes.length - 1].min
                    when :lowest
                      attributes.length - 1
                    else
                      current_index
                    end

        attributes.insert(new_index, attributes.delete_at(current_index)) if new_index != current_index
        row[:group].attributes = attributes

        persist_groups(active_groups).tap do |call|
          call.result = row[:group] if call.success?
        end
      end

      def drop_row(target_id:, position:)
        row = find_row(@row_key)

        # If dropping to inactive
        if target_id.to_s == INACTIVE_TARGET
          # Remove from source group if it was in one
          if row
            source_attributes = row[:group].attributes.dup
            source_attributes.delete_at(row[:index])
            row[:group].attributes = source_attributes
          end
          # Persist and return (attribute is now inactive)
          return persist_groups(active_groups).tap do |call|
            call.result = row&.dig(:group) if call.success?
          end
        end

        # For active target, add to target group (regardless of where it came from)
        target_group = find_attribute_section(target_id)
        Rails.logger.debug("drop_row: target_id=#{target_id.inspect}, found_group=#{target_group.present?}, active_groups=#{active_groups.map { |g| { key: g.key, display_name: g.display_name } }}")
        unless target_group
          return failure_with_message(I18n.t("types.edit.form_configuration.not_found"))
        end

        # Remove from source if it was in a group
        if row
          source_attributes = row[:group].attributes.dup
          source_attributes.delete_at(row[:index])
          row[:group].attributes = source_attributes
        end

        # Add to target group at the specified position
        target_attributes = target_group.attributes.dup
        insert_position = [position.to_i - 1, 0].max
        insert_position = [insert_position, target_attributes.length].min

        target_attributes.insert(insert_position, @row_key)
        target_group.attributes = target_attributes

        persist_groups(active_groups).tap do |call|
          call.result = target_group if call.success?
        end
      end

      def not_found_message(action:, **details)
        #binding.pry
        base_message = I18n.t("types.edit.form_configuration.not_found")
        context = diagnostic_context(action:, **details)

        Rails.logger.warn("[form_configuration_rows.update_service] not_found #{context}")

        return base_message unless Rails.env.development?

        "#{base_message} #{context}"
      end

      def diagnostic_context(action:, **details)
        "type_id=#{type.id} row_key=#{@row_key.inspect} action=#{action} details=#{details.inspect} " \
          "active_groups=#{active_groups.map { |group|
            {
              key: group.key,
              display_name: group.display_name,
              translated_key: group.translated_key,
              group_type: group.group_type,
              attributes: (group.attributes if group.group_type == :attribute)
            }
          }.inspect}"
      end
    end
  end
end
