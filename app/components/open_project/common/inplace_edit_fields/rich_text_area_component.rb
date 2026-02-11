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
      class RichTextAreaComponent < ViewComponent::Base
        attr_reader :form, :attribute, :model

        def self.display_class
          DisplayFields::RichTextAreaComponent
        end

        def initialize(form:, attribute:, model:, **system_arguments)
          super()
          @form = form
          @attribute = attribute
          @model = model
          @system_arguments = system_arguments
          @system_arguments[:classes] = class_names(
            @system_arguments[:classes],
            "op-inplace-edit-field--text-area"
          )
          @system_arguments[:label] ||= model.class.human_attribute_name(attribute)

          @system_arguments[:rich_text_options] ||= {}
          @system_arguments[:rich_text_options][:primerized] = true
        end

        def call
          form.rich_text_area(name: attribute, **@system_arguments)

          form.group(layout: :horizontal, justify_content: :flex_end) do |button_group|
            button_group.submit(name: :reset,
                                type: :submit,
                                label: I18n.t(:button_cancel),
                                scheme: :default,
                                formaction: inplace_edit_field_reset_path(model: model.class.name, id: model.id, attribute:),
                                formmethod: :get,
                                test_selector: "op-inplace-edit-field--textarea-cancel")
            button_group.submit(name: :submit,
                                label: I18n.t(:button_save),
                                scheme: :primary,
                                test_selector: "op-inplace-edit-field--textarea-save")
          end
        end
      end
    end
  end
end
