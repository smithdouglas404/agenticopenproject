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
      module DisplayFields
        class DisplayFieldComponent < ViewComponent::Base
          include OpenProject::TextFormatting

          attr_reader :model, :attribute, :writable

          def initialize(model:, attribute:, writable:, **system_arguments)
            super()
            @model = model
            @attribute = attribute
            @writable = writable
            @system_arguments = system_arguments
          end

          def render_display_value
            value = model.public_send(attribute)

            if value.present?
              format_text(value)
            else
              "–"
            end
          end

          def display_field_arguments
            @display_field_arguments ||= {
              classes: "op-inplace-edit--display-field #{'op-inplace-edit--display-field_editable' if writable}",
              data: {
                controller: "inplace-edit",
                inplace_edit_url_value: edit_url,
                action: writable ? "click->inplace-edit#request" : ""
              }
            }
          end

          def call
            render(Primer::BaseComponent.new(tag: :div, **display_field_arguments)) do
              render_display_value
            end
          end

          private

          def edit_url
            inplace_edit_field_edit_path(
              model: model.class.name,
              id: model.id,
              attribute:,
              system_arguments_json: @system_arguments.to_json
            )
          end
        end
      end
    end
  end
end
