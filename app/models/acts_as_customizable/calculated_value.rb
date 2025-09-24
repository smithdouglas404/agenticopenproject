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

      remove_calculated_value_errors!(custom_fields.map(&:id))

      result, errors = calculate_custom_fields_result(
        given:,
        to_compute: calculated_value_fields_to_compute(custom_fields:, enabled_ids:)
      ).values_at(:result, :errors)

      self.custom_field_values = custom_fields.to_h { [it.id, result[it.column_name]] }

      refresh_calculation_errors!(given, enabled_ids, custom_fields, result, errors)
    end

    private

    def calculate_custom_fields_result(given:, to_compute:)
      calculator = CustomField::CalculatedValue.calculator_instance
      calculator.store(given)

      calculation = calculator.solve(to_compute, &:itself)

      result = calculation.transform_values do |value|
        value.is_a?(Numeric) ? value : nil
      end

      errors = calculation.transform_values do |value|
        case value
        when Dentaku::ZeroDivisionError
          :zero_division
        when Dentaku::ArgumentError
          :missing_value
        when Dentaku::UnboundVariableError
          [:unbound_variable, value.unbound_variables]
        when Numeric
          # Calculation succeeded -> no error
          nil
        else
          :unknown
        end
      end.compact

      { result:, errors: }
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

    def refresh_calculation_errors!(given_cfs, enabled_ids, calculated_fields, result, errors)
      return unless is_a?(Project)

      enabled_calculated_fields = calculated_fields.filter { it.id.in?(enabled_ids) }
      create_new_calculated_value_errors!(enabled_calculated_fields, given_cfs, result, errors)
    end

    def create_new_calculated_value_errors!(enabled_calculated_fields, given_cfs, result, errors)
      errors.each do |cf_id, error|
        cf_id = to_id(cf_id)

        case error
        when :zero_division
          create_calculated_value_error(cf_id, "ERROR_MATHEMATICAL")
        when :missing_value
          create_errors_for_missing_attributes(given_cfs, enabled_calculated_fields, result, errors)
        when Array
          if error.first == :unbound_variable
            disabled_fields = error.last.map { to_id(it) }
            create_calculated_value_error(cf_id, "ERROR_DISABLED_VALUE", disabled_fields)
          else
            create_calculated_value_error(cf_id, "ERROR_UNKNOWN")
          end
        else
          create_calculated_value_error(cf_id, "ERROR_UNKNOWN")
        end
      end
    end

    def create_calculated_value_error(custom_field_id, error_code, missing_custom_field_ids = [])
      CalculatedValueError.create(customized: self, custom_field_id:, error_code:, missing_custom_field_ids:)
    end

    def create_errors_for_missing_attributes(referenced_values, calculated_fields, result, errors)
      cf_ids_with_missing_values = referenced_values.filter_map { |k, v| to_id(k) if v.nil? }

      missing_values = errors.filter_map { |k, v| to_id(k) if v == :missing_value }
      calculated_fields_with_missing_values = calculated_fields.filter do |cv|
        missing_values.include?(cv.id)
      end

      calculated_fields_with_missing_values.each do |cv|
        handle_missing_value_error(cv, cf_ids_with_missing_values) ||
          handle_indirectly_missing_value_error(cv, calculated_fields, result)
      end
    end

    def remove_calculated_value_errors!(custom_field_ids = [])
      return if custom_field_ids.empty?

      CalculatedValueError.where(customized: self, custom_field_id: custom_field_ids).delete_all
    end

    # Creates an error if a value that is directly required for the calculation is missing.
    # This is true for example for a formula like `2 + {{cf_12}}` where `cf_12` has no value set.
    def handle_missing_value_error(calculated_value, cf_ids_with_missing_values)
      missing_values_for_this_cv = calculated_value.formula_referenced_custom_field_ids & cf_ids_with_missing_values

      if missing_values_for_this_cv.any?
        create_calculated_value_error(calculated_value.id, "ERROR_MISSING_VALUE", missing_values_for_this_cv)
      end
    end

    # Creates an error if a value that is indirectly required for the calculation is missing.
    # This is true for example for a formula like `2 + {{cf_12}}` where `cf_12` is a calculated value itself
    # that cannot be calculated because it references a custom field with no value set.
    def handle_indirectly_missing_value_error(calculated_value, calculated_fields, result)
      cf_ids_with_results = result.filter_map { |cf_id, v| to_id(cf_id) unless v.nil? }
      cf_ids_in_formula_without_result = calculated_value.formula_referenced_custom_field_ids - cf_ids_with_results

      indirectly_missing = cf_ids_in_formula_without_result.filter do |ref_id|
        calculated_fields.any? { it.id == ref_id }
      end

      return false if indirectly_missing.empty?

      create_calculated_value_error(calculated_value.id, "ERROR_MISSING_VALUE", indirectly_missing)
    end
  end
end
