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

module CalculatedValues
  class ErrorHandler
    class ErrorContext
      attr_reader :custom_field_id, :error_code, :missing_custom_field_ids

      def initialize(custom_field_id:, error_code:, missing_custom_field_ids: [])
        @custom_field_id = custom_field_id
        @error_code = error_code
        @missing_custom_field_ids = missing_custom_field_ids
      end

      def create_calculated_value_error!(customized)
        CalculatedValueError.create(
          customized:,
          custom_field_id:,
          error_code:,
          missing_custom_field_ids:
        )
      end
    end

    def self.handle_calculation_errors(customized, calculation_result, given_values, calculated_fields)
      new(customized, calculation_result, given_values, calculated_fields).handle_errors
    end

    def initialize(customized, calculation_result, given_values, calculated_fields)
      @customized = customized
      @calculation_result = calculation_result
      @given_values = given_values
      @calculated_fields = calculated_fields
    end

    def handle_errors
      return unless should_create_errors?

      error_contexts = build_error_contexts
      create_error_records!(error_contexts)
    end

    private

    attr_reader :customized, :calculation_result, :given_values, :calculated_fields

    def should_create_errors?
      customized.is_a?(Project)
    end

    def build_error_contexts
      calculation_result[:errors].filter_map do |cf_id, error|
        build_error_context(cf_id, error)
      end
    end

    def build_error_context(cf_id, error)
      custom_field_id = to_id(cf_id)

      case error
      when :zero_division
        ErrorContext.new(custom_field_id:, error_code: "ERROR_MATHEMATICAL")
      when :missing_value
        build_missing_value_error_context(custom_field_id)
      when Array
        if error.first == :unbound_variable
          disabled_fields = error.last.map { to_id(it) }
          ErrorContext.new(custom_field_id:, error_code: "ERROR_DISABLED_VALUE", missing_custom_field_ids: disabled_fields)
        else
          ErrorContext.new(custom_field_id:, error_code: "ERROR_UNKNOWN")
        end
      else
        ErrorContext.new(custom_field_id:, error_code: "ERROR_UNKNOWN")
      end
    end

    def build_missing_value_error_context(custom_field_id)
      missing_values = find_missing_values_for_field(custom_field_id)
      ErrorContext.new(custom_field_id:, error_code: "ERROR_MISSING_VALUE", missing_custom_field_ids: missing_values)
    end

    def find_missing_values_for_field(custom_field_id)
      calculated_field = calculated_fields.find { it.id == custom_field_id }
      return [] unless calculated_field

      direct_missing = calculated_field.formula_referenced_custom_field_ids & cf_ids_with_missing_values
      indirect_missing = find_indirect_missing_values(calculated_field)

      direct_missing + indirect_missing
    end

    def find_indirect_missing_values(calculated_field)
      cf_ids_with_results = calculation_result[:values].filter_map { |cf_id, v| to_id(cf_id) unless v.nil? }
      cf_ids_in_formula_without_result = calculated_field.formula_referenced_custom_field_ids - cf_ids_with_results

      cf_ids_in_formula_without_result.filter do |ref_id|
        calculated_fields.any? { it.id == ref_id }
      end
    end

    def cf_ids_with_missing_values
      @cf_ids_with_missing_values ||= given_values.filter_map { |k, v| to_id(k) if v.nil? }
    end

    def create_error_records!(error_contexts)
      error_contexts.each do |context|
        context.create_calculated_value_error!(customized)
      end
    end

    def to_id(cf_id)
      cf_id.sub("cf_", "").to_i
    end
  end
end
