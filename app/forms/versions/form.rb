# frozen_string_literal: true

# -- copyright
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
# ++
module Versions
  class Form < ApplicationForm
    include CustomFields::CustomFieldRendering
    include VersionsHelper
    include WikiHelper

    form do |f|
      # Round-trip the version kind (sprint/release) so new versions are created with
      # the kind chosen on the originating screen. Not user-editable here.
      f.hidden(name: :kind)

      f.text_field(
        name: :name,
        label: attribute_name(:name),
        required: true,
        input_width: :large,
        autocomplete: :off
      )

      f.text_field(
        name: :description,
        label: attribute_name(:description),
        input_width: :large
      )

      f.select_list(
        name: :status,
        label: attribute_name(:status),
        input_width: :xsmall
      ) do |list|
        contract.assignable_statuses.each do |s|
          list.option(
            label: I18n.t("version_status_#{s}"),
            value: s,
            selected: version.status == s
          )
        end
      end

      f.select_list(
        name: :wiki_page_title,
        label: I18n.t(:label_wiki_page),
        include_blank: true,
        disabled: wiki_pages_disabled?,
        input_width: :large
      ) do |list|
        wiki_page_options_for_select(
          contract.assignable_wiki_pages.includes(:parent),
          placeholder: false,
          ids: false
        ).each do |label, value|
          list.option(
            label:,
            value:,
            selected: version.wiki_page_title == value
          )
        end
      end

      f.single_date_picker(
        name: :start_date,
        label: attribute_name(:start_date),
        input_width: :xsmall,
        leading_visual: { icon: :calendar }
      )

      f.single_date_picker(
        name: :effective_date,
        label: attribute_name(:effective_date),
        input_width: :xsmall,
        leading_visual: { icon: :calendar }
      )

      f.select_list(
        name: :sharing,
        label: attribute_name(:sharing),
        input_width: :small
      ) do |list|
        contract.assignable_sharings.each do |v|
          list.option(
            label: format_version_sharing(v),
            value: v,
            selected: version.sharing == v
          )
        end
      end

      if backlogs_enabled?
        setting = version_setting_for_project

        if OpenProject::FeatureDecisions.scrum_projects_active?
          # We originally planned to render a check_box here. But since this changes the way Rails will submit the parameters,
          # this would require changing the controller or services, too. With a feature flag in place, this adds quite a
          # lot of complexity.
          # To circumvent this, we will use a select list with two options for now. This will not require any changes to
          # controllers or services. We can fix this once the feature flag has been removed.
          f.select_list(
            name: "version[version_settings_attributes][][display]",
            scope_name_to_model: false,
            label: I18n.t(:label_used_as_backlog),
            input_width: :small
          ) do |list|
            # Maintain the current setting for the sake of migrating sprints to versions later on
            current_display_setting = setting.display
            value_for_no = if current_display_setting == VersionSetting::DISPLAY_RIGHT || current_display_setting.nil?
                             VersionSetting::DISPLAY_NONE
                           else
                             current_display_setting
                           end

            list.option(label: I18n.t(:general_text_no),
                        value: value_for_no,
                        selected: setting.display != VersionSetting::DISPLAY_RIGHT)

            list.option(label: I18n.t(:general_text_yes),
                        value: VersionSetting::DISPLAY_RIGHT,
                        selected: setting.display == VersionSetting::DISPLAY_RIGHT)
          end
        else
          f.select_list(
            name: "version[version_settings_attributes][][display]",
            scope_name_to_model: false,
            label: I18n.t(:label_column_in_backlog),
            input_width: :small
          ) do |list|
            position_display_options.each do |label, value|
              list.option(label:, value:, selected: setting.display == value)
            end
          end
        end

        if setting.persisted?
          f.hidden(
            name: "version[version_settings_attributes][][id]",
            value: setting.id,
            scope_name_to_model: false
          )
        end
      end

      render_custom_fields(form: f)

      f.submit(
        name: :submit,
        label: submit_label,
        scheme: :primary
      )
    end

    def initialize(project: nil, submit_label: I18n.t(:button_save))
      super()
      @project = project
      @submit_label = submit_label
    end

    private

    attr_reader :submit_label, :project

    def version
      model
    end

    def contract
      @contract ||= if version.new_record?
                      Versions::CreateContract.new(version, User.current)
                    else
                      Versions::UpdateContract.new(version, User.current)
                    end
    end

    def custom_fields
      version.available_custom_fields
    end

    def wiki_pages_disabled?
      contract.assignable_wiki_pages.none?
    end

    def backlogs_enabled?
      resolved_project.backlogs_enabled?
    end

    def resolved_project
      @project || version.project
    end

    def version_setting_for_project
      setting = version.version_settings.detect { |vs| vs.project_id == resolved_project.id || vs.project_id.nil? }
      setting || version.version_settings.new(display: VersionSetting::DISPLAY_LEFT, project: resolved_project)
    end

    def position_display_options
      [VersionSetting::DISPLAY_NONE,
       VersionSetting::DISPLAY_LEFT,
       VersionSetting::DISPLAY_RIGHT].map { |s| [humanize_display_option(s), s] }
    end

    def humanize_display_option(option)
      case option
      when VersionSetting::DISPLAY_NONE
        I18n.t("version_settings_display_option_none")
      when VersionSetting::DISPLAY_LEFT
        I18n.t("version_settings_display_option_left")
      when VersionSetting::DISPLAY_RIGHT
        I18n.t("version_settings_display_option_right")
      end
    end
  end
end
