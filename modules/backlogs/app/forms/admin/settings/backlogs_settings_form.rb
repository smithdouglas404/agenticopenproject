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

module Admin
  module Settings
    class BacklogsSettingsForm < ApplicationForm
      include ::Settings::FormHelper

      form do |f|
        unless scrum_projects_active?
          f.autocompleter(
            name: :story_types,
            label: I18n.t(:backlogs_story_type),
            caption: setting_caption(:plugin_openproject_backlogs, :story_types),
            autocomplete_options: {
              multiple: true,
              closeOnSelect: false,
              clearable: false,
              decorated: true,
              data: {
                admin__backlogs_settings_target: "storyTypes",
                test_selector: "story_type_autocomplete"
              }
            }
          ) do |list|
            available_types.each do |label, value|
              active = value.in?(Story.types)
              in_use = Task.type == value

              list.option(
                label:,
                value:,
                selected: active,
                disabled: in_use
              )
            end
          end

          f.autocompleter(
            name: :task_type,
            label: I18n.t(:backlogs_task_type),
            caption: setting_caption(:plugin_openproject_backlogs, :task_type),
            input_width: :small,
            autocomplete_options: {
              multiple: false,
              closeOnSelect: true,
              clearable: false,
              decorated: true,
              data: {
                admin__backlogs_settings_target: "taskType",
                test_selector: "task_type_autocomplete"
              }
            }
          ) do |list|
            available_types.each do |label, value|
              active = Task.type == value
              in_use = value.in?(Story.types)

              list.option(
                label:,
                value:,
                selected: active,
                disabled: in_use
              )
            end
          end
        end

        f.radio_button_group(
          name: :points_burn_direction,
          label: I18n.t(:backlogs_points_burn_direction)
        ) do |group|
          group.radio_button(
            label: I18n.t(:label_points_burn_up),
            value: "up"
          )
          group.radio_button(
            label: I18n.t(:label_points_burn_down),
            value: "down"
          )
        end

        unless scrum_projects_active?
          f.text_field(
            name: :wiki_template,
            label: I18n.t(:backlogs_wiki_template),
            input_width: :medium
          )
        end

        f.submit(scheme: :primary, name: :apply, label: I18n.t(:button_save))
      end

      private

      def available_types
        Type.pluck(:name, :id)
      end

      def scrum_projects_active?
        OpenProject::FeatureDecisions.scrum_projects_active?
      end
    end
  end
end
