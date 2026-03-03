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

module Overviews
  module ProjectCustomFields
    class ItemComponent < ShowComponent
      private

      def show_comment? = false

      def value_wrapper_attributes
        if allowed_to_edit?
          if calculated_value? && !has_comment?
            non_editable_wrapper(id: calculated_value_tooltip_id)
          else
            modal_wrapper
          end
        elsif has_comment?
          modal_wrapper
        else
          non_editable_wrapper
        end
      end

      def allowed_to_edit?
        User.current.allowed_in_project?(:edit_project_attributes, @project)
      end

      def modal_wrapper
        action_label_key = allowed_to_edit? ? :label_edit_x : :label_view_x

        url = if allowed_to_edit?
                edit_project_custom_field_path(project_id: @project, id: @project_custom_field)
              else
                project_custom_field_path(project_id: @project, id: @project_custom_field)
              end

        {
          tag: :div,
          classes: "project-custom-field-clickable",
          data: {
            controller: "project-custom-field-modal async-dialog",
            "project-custom-field-modal-url-value": url,
            action: "click->project-custom-field-modal#open " \
                    "keydown.enter->project-custom-field-modal#open " \
                    "keydown.space->project-custom-field-modal#open " \
                    "project-custom-field-modal:open-dialog->async-dialog#handleOpenDialog"
          },
          aria: {
            label: [
              I18n.t(action_label_key, x: @project_custom_field.name),
              I18n.t(:label_value_x, x: accessible_value_text)
            ].join(", ")
          },
          role: "button",
          tabindex: 0,
          test_selector: "project-custom-field-modal-button-#{@project_custom_field.id}"
        }
      end

      def non_editable_wrapper(**)
        {
          tag: :div,
          classes: "project-custom-field-non-editable",
          aria: {
            disabled: true,
            label: [
              @project_custom_field.name,
              I18n.t(:label_value_x, x: accessible_value_text)
            ].join(", ")
          },
          tabindex: 0,
          **
        }
      end
    end
  end
end
