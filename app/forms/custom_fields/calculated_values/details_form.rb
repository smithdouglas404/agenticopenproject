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
  module CalculatedValues
    class DetailsForm < ApplicationForm
      form do |details_form|
        if model.new_record?
          details_form.hidden(name: :field_format)
          details_form.hidden(name: :type, scope_name_to_model: false)
        end

        details_form.text_field(
          name: :name,
          label: I18n.t(:label_name),
          required: true
        )

        details_form.select_list(
          name: :custom_field_section_id,
          label: I18n.t("activerecord.attributes.project_custom_field.custom_field_section"),
          required: true
        ) do |li|
          ProjectCustomFieldSection.find_each do |cs|
            li.option(value: cs.id, label: cs.name)
          end
        end

        details_form.pattern_input(
          name: :formula,
          value: model.formula_string,
          suggestions: formula_suggestions,
          label: I18n.t(:label_formula),
          required: true,
          caption: I18n.t("custom_fields.instructions.formula")
        )

        details_form.check_box(
          name: :is_required,
          label: I18n.t("activerecord.attributes.project_custom_field.is_required"),
          caption: I18n.t("custom_fields.instructions.is_required_for_project")
        )

        details_form.check_box(
          name: :admin_only,
          label: I18n.t("activerecord.attributes.custom_field.admin_only"),
          caption: I18n.t("custom_fields.instructions.admin_only")
        )

        details_form.submit(name: :submit, label: I18n.t(:button_save), scheme: :primary)
      end

      private

      def formula_suggestions
        operators = CustomField::CalculatedValue::MATH_OPERATORS_FOR_FORMULA
                      # Hide % from the suggestions as it can be used as either modulo or percentage.
                      .reject { it == "%" }
                      .map do |op|
          # Insert operators as plain text nodes instead of tokens, since displaying them as tokens would result
          # in too much visual clutter. We still want to offer autocompletion for them.
          { key: op, label: op, insert_as_text: true, enabled: true }
        end

        custom_fields = model.usable_custom_field_references_for_formula.map do |cf|
          { key: "cf_#{cf.id}", label: cf.name, enabled: true }
        end

        {
          custom_fields: { title: I18n.t("label_custom_field_plural"), tokens: custom_fields },
          operators: { title: I18n.t("label_mathematical_operators"), tokens: operators }
        }
      end
    end
  end
end
