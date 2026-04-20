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
    include OpTurbo::ComponentStream
    include WorkPackageTypes::FormConfigurationComponentStreams

    def create
      call = ::WorkPackageTypes::FormConfigurationSections::CreateService
        .new(user: current_user, type: @type)
        .call(group_type: params[:group_type], query_props: params[:query])

      if call.success?
        update_sections_via_turbo_stream(editing_section_key: call.result.key)
      else
        render_form_configuration_error(call)
      end

      respond_with_turbo_streams(status: turbo_status_for(call))
    rescue StandardError => e
      Rails.logger.error("[form_configuration_sections.create] #{e.class}: #{e.message}\n#{e.backtrace&.first(20)&.join("\n")}")

      if Rails.env.development?
        render_error_flash_message_via_turbo_stream(message: "#{e.class}: #{e.message}")
        respond_with_turbo_streams(status: :internal_server_error)
      else
        raise
      end
    end

    def edit
      replace_section_via_turbo_stream(key: section_key_param, edit_mode: true)

      respond_with_turbo_streams
    end

    def cancel_edit
      section = find_section(section_key_param)
      return head :not_found if section.nil?

      if implicit_section?(section)
        call = ::WorkPackageTypes::FormConfigurationSections::DeleteService
          .new(user: current_user, type: @type, section_key: section_key_param)
          .call

        if call.success?
          update_form_configuration_via_turbo_stream
        else
          render_form_configuration_error(call)
        end

        respond_with_turbo_streams(status: turbo_status_for(call))
      else
        replace_section_via_turbo_stream(key: params[:key], edit_mode: false)
        respond_with_turbo_streams
      end
    end

    def update
      call = ::WorkPackageTypes::FormConfigurationSections::UpdateService
        .new(user: current_user, type: @type, section_key: section_key_param)
        .call(name: section_params[:name])

      if call.success?
        update_form_configuration_via_turbo_stream
      else
        render_form_configuration_error(call)
      end

      respond_with_turbo_streams(status: turbo_status_for(call))
    end

    def destroy
      call = ::WorkPackageTypes::FormConfigurationSections::DeleteService
        .new(user: current_user, type: @type, section_key: section_key_param)
        .call

      if call.success?
        update_form_configuration_via_turbo_stream
      else
        render_form_configuration_error(call)
      end

      respond_with_turbo_streams(status: turbo_status_for(call))
    end

    def drop
      call = ::WorkPackageTypes::FormConfigurationSections::UpdateService
        .new(user: current_user, type: @type, section_key: section_key_param)
        .call(position: params[:position])

      if call.success?
        update_sections_via_turbo_stream
      else
        render_form_configuration_error(call)
      end

      respond_with_turbo_streams(status: turbo_status_for(call))
    end

    def move
      call = ::WorkPackageTypes::FormConfigurationSections::UpdateService
        .new(user: current_user, type: @type, section_key: section_key_param)
        .call(move_to: params[:move_to])

      if call.success?
        update_sections_via_turbo_stream
      else
        render_form_configuration_error(call)
      end

      respond_with_turbo_streams(status: turbo_status_for(call))
    end

    def update_query
      call = ::WorkPackageTypes::FormConfigurationSections::UpdateService
        .new(user: current_user, type: @type, section_key: section_key_param)
        .call(query_props: params[:query])

      if call.success?
        head :ok
      else
        render_form_configuration_error(call)
        respond_with_turbo_streams(status: turbo_status_for(call))
      end
    end

    private

    def section_params
      params.expect(section: [:name])
    end

    def find_section(key)
    
      @type.attribute_groups.find do |group|
        [
          group.key,
          group.display_name,
          group.translated_key
        ].compact.map(&:to_s).include?(key.to_s)
      end
    end

    def section_key_param
      params[:key] || params[:id]
    end

    def implicit_section?(section)
      section.key.to_s.match?(::WorkPackageTypes::FormConfiguration::BaseService::UUID_REGEX)
    end

    def turbo_status_for(call)
      call.success? ? :ok : :unprocessable_entity
    end
  end
end
