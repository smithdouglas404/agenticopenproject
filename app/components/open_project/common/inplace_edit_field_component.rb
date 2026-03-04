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
    class InplaceEditFieldComponent < ViewComponent::Base
      include OpTurbo::Streamable

      attr_reader :model, :attribute, :enforce_edit_mode

      def initialize(model:, attribute:, enforce_edit_mode: false,
                     update_registry: OpenProject::InplaceEdit::UpdateRegistry, **system_arguments)
        super()
        @model = model
        @attribute = attribute
        @enforce_edit_mode = enforce_edit_mode
        @update_registry = update_registry
        @system_arguments = system_arguments
        @system_arguments[:id] = system_arguments[:id] || SecureRandom.uuid
      end

      def field_class
        OpenProject::InplaceEdit::FieldRegistry.fetch(attribute)
      end

      def edit_field_component(form)
        field_class.new(
          form:,
          attribute:,
          model:,
          **@system_arguments
        )
      end

      def display_field_class
        if field_class.respond_to?(:display_class)
          field_class.display_class
        else
          InplaceEditFields::DisplayFields::DisplayFieldComponent
        end
      end

      def display_field_component
        return nil if display_field_class.nil?

        display_field_class.new(model:, attribute:, writable: writable?, **@system_arguments)
      end

      def wrapper_key
        model_class = @model.class.name.parameterize(separator: "_")
        "op-inplace-edit-field--#{model_class}-#{model.id}--#{attribute.name}--#{@system_arguments[:id]}"
      end

      def wrapper_test_selector
        "op-inplace-edit-field"
      end

      private

      def writable?
        return @writable if defined?(@writable)

        contract_class = @update_registry.fetch_contract(model)
        @writable =
          if contract_class.present?
            contract_class.new(model, User.current).writable?(attribute)
          else
            false
          end
      end
    end
  end
end
