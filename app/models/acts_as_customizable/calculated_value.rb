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

module ActsAsCustomizable::CalculatedValue
  extend ActiveSupport::Concern

  included do
    def enabled_custom_field_ids
      fail NoMethodError, <<~DESCRIPTION.squish
        Required for calculated_value custom fields in calculate_custom_fields method.
        Define which fields are enabled, not to be confused with visible, as enabled should not depend on current user.
      DESCRIPTION
    end

    def calculate_custom_fields(custom_fields)
      return if custom_fields.empty?

      unless custom_fields.all?(&:field_format_calculated_value?)
        fail ArgumentError,
             "Expected array of calculated value custom fields"
      end

      enabled_ids = enabled_custom_field_ids
      given = calculated_value_fields_given(custom_fields:, enabled_ids:)
      result = calculate_custom_fields_result(
        given:,
        to_compute: calculated_value_fields_to_compute(custom_fields:, enabled_ids:)
      )

      self.custom_field_values = custom_fields.to_h { [it.id, result[it.column_name]] }
      refresh_calculation_errors!(given, custom_fields.map(&:id), result)
    end

    private

    def calculate_custom_fields_result(given:, to_compute:)
      calculator = CustomField::CalculatedValue.calculator_instance
      calculator.store(given)

      calculator.solve(to_compute).transform_values { |value| value == :undefined ? nil : value }
    end

    def calculated_value_fields_given(custom_fields:, enabled_ids:)
      referenced_ids = custom_fields.flat_map(&:formula_referenced_custom_field_ids)
      given_ids = (enabled_ids & referenced_ids) - custom_fields.map(&:id)

      custom_field_values(all: true)
        .select { it.custom_field_id.in?(given_ids) }
        .to_h { [it.custom_field.column_name, it.typed_value] }
    end

    def calculated_value_fields_to_compute(custom_fields:, enabled_ids:)
      custom_fields
        .select { it.id.in?(enabled_ids) }
        .to_h { [it.column_name, it.formula_str_without_patterns] }
    end

    def to_id(cf_id)
      cf_id.sub("cf_", "").to_i
    end

    def refresh_calculation_errors!(referenced_values, calculated_field_ids, result)
      return unless is_a?(Project)

      failed_calculations, successful_calculations = result.partition do |_, calculation_result|
        calculation_result.nil?
      end

      successfully_calculated_cfs = successful_calculations.map { |cf_id, _| to_id(cf_id) }
      remove_calculated_value_errors(successfully_calculated_cfs)

      create_errors_for_missing_attributes(referenced_values, calculated_field_ids)

      failed_calculations.to_h.each_key do |cf_id|
        create_calculated_value_error(to_id(cf_id), "ERROR_MATHEMATICAL")
      end
    end

    def create_calculated_value_error(custom_field_id, error_code)
      CalculatedValueError.create(project: self, custom_field_id:, error_code:)
    end

    def create_errors_for_missing_attributes(referenced_values, calculated_field_ids)
      cf_ids_with_missing_values = referenced_values.filter_map { |k, v| to_id(k) if v.nil? }
      cf_ids_with_missing_values.each do |_missing_cf_id|
        calculated_field_ids.each do |calculated_cf_id|
          # TODO: insert missing custom field name into the error message:
          create_calculated_value_error(calculated_cf_id, "ERROR_MISSING_VALUE")
        end
      end
    end

    def remove_calculated_value_errors(custom_field_ids = [])
      return if custom_field_ids.empty?

      CalculatedValueError.where(project: self, custom_field_id: custom_field_ids).delete_all
    end
  end
end
