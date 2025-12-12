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

module CustomFields
  module CustomOptions
    class BaseRowComponent < ::RowComponent
      with_collection_parameter :row

      alias :custom_option :model

      delegate :form, :custom_field, to: :table

      attr_reader :index, :templated

      def initialize(row_counter:, templated: false, **)
        @index = row_counter || "INDEX"
        @templated = templated

        super
      end

      def button_links
        [
          primer_action_button(
            icon: :"move-to-top",
            label: t(:label_sort_highest),
            data: { action: "admin--custom-fields#moveRowToTheTop" }
          ),

          primer_action_button(
            icon: :"arrow-up",
            label: t(:label_sort_higher),
            data: { action: "admin--custom-fields#moveRowUp" }
          ),

          primer_action_button(
            icon: :"arrow-down",
            label: t(:label_sort_lower),
            data: { action: "admin--custom-fields#moveRowDown" }
          ),

          primer_action_button(
            icon: :"move-to-bottom",
            label: t(:label_sort_lowest),
            data: { action: "admin--custom-fields#moveRowToTheBottom" }
          ),

          primer_action_button(
            icon: :trash,
            label: t(:button_delete),
            data: {
              action: "admin--custom-fields#removeOption",
              turbo_method: :delete,
              turbo_confirm: t(:"custom_fields.confirm_destroy_option")
            }
          )
        ]
      end

      def row_css_class
        "dragula-element custom-option-row"
      end

      def prefix
        raise NotImplementedError
      end

      private

      def primer_text_field(name:, **)
        with_form do |f|
          f.text_field(name:, visually_hide_label: true, **)
        end
      end

      def primer_check_box(name:, **, &)
        with_form do |f|
          f.check_box(name:, visually_hide_label: true, **, &)
        end
      end

      def primer_action_button(icon:, label:, **system_arguments)
        render(
          Primer::Beta::IconButton.new(
            scheme: :invisible,
            icon:,
            tooltip_direction: :se,
            aria: { label: },
            **system_arguments
          )
        )
      end

      def with_form(&)
        form.fields_for(prefix, custom_option) do |fields|
          render_inline_form(fields, &)
        end
      end
    end
  end
end
