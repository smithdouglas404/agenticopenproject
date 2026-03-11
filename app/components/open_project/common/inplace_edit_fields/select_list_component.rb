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

module OpenProject
  module Common
    module InplaceEditFields
      class SelectListComponent < BaseFieldComponent
        def self.display_class
          DisplayFields::SelectListComponent
        end

        def initialize(form:, attribute:, model:, show_action_buttons: true, **system_arguments)
          super

          @system_arguments[:autocomplete_options] ||= {}
          @system_arguments[:autocomplete_options][:model] ||= { id: model.id, name: model.name }
          @system_arguments[:autocomplete_options][:inputName] ||= attribute
          @system_arguments[:autocomplete_options][:wrapper_id] ||= @system_arguments[:wrapper_id]
          if @system_arguments[:autocomplete_options][:focusDirectly].nil?
            @system_arguments[:autocomplete_options][:focusDirectly] =
              true
          end
          if @system_arguments[:autocomplete_options][:closeOnSelect].nil?
            @system_arguments[:autocomplete_options][:closeOnSelect] =
              false
          end
        end

        def call
          if custom_field?
            render_custom_field_input
          else
            render_autocompleter
          end

          comment_field_if_enabled(form)

          if show_action_buttons
            form.group(layout: :horizontal, justify_content: :flex_end) do |button_group|
              button_group.submit(name: :reset,
                                  type: :submit,
                                  label: I18n.t(:button_cancel),
                                  scheme: :default,
                                  formaction: inplace_edit_field_reset_path(model: model.class.name, id: model.id, attribute:),
                                  formmethod: :get)
              button_group.submit(name: :submit,
                                  label: I18n.t(:button_save),
                                  scheme: :primary)
            end
          end
        end

        private

        def render_custom_field_input
          input_class = if custom_field.multi_value?
                          CustomFields::Inputs::MultiSelectList
                        else
                          CustomFields::Inputs::SingleSelectList
                        end

          # Use fields_for to create the proper context for custom field inputs
          form.fields_for(:custom_field_values) do |builder|
            input_class.new(builder, custom_field:, object: model, **@system_arguments[:autocomplete_options])
          end
        end

        def render_autocompleter
          form.autocompleter(name: attribute, **@system_arguments)
        end
      end
    end
  end
end
