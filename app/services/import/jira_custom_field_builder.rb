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

module Import
  class JiraCustomFieldBuilder
    # Maps the Jira schema `custom` field suffix (part after the last `:`) to an OP field format.
    # Takes precedence over the type-based mapping below.
    JIRA_CUSTOM_SUFFIX_TO_OP_FORMAT = {
      "url" => "link",
      "userpicker" => "user",
      "multiuserpicker" => "user",
      "textarea" => "text" # TODO: format depends on the renderer for which no API endpoint exists to find out
    }.freeze

    # Maps the Jira schema `type` field to an OP field format.
    JIRA_TYPE_TO_OP_FORMAT = {
      "string" => "string",
      "text" => "text",
      "number" => "float",
      "date" => "date",
      "datetime" => "date", # TODO: loss of precision
      "option" => "list",
      "user" => "user",
      "any" => "string"
    }.freeze

    # Maps the Jira schema `items` field (for array types) to an OP field format.
    JIRA_ARRAY_ITEMS_TO_OP_FORMAT = {
      "option" => "list",
      "user" => "user"
    }.freeze

    attr_reader :jira_project, :jira_field, :values

    def initialize(jira_field, jira_project, values)
      @jira_field = jira_field
      @jira_project = jira_project
      @values = values
      @import_name = jira_field.payload["name"]
    end

    def find_existing_custom_field
      existing_cf = custom_field_by_name(@import_name) if %w[hierarchy list].exclude?(format)
      return existing_cf if existing_cf&.field_format == format

      @import_name = unique_custom_field_name
      nil
    end

    def custom_field_settings
      [@import_name, format]
    end

    def custom_field_parameters
      params = {}
      if format == "list"
        params[:multi_value] = jira_field_multi_value?
        options = collect_list_options(values)
        params[:possible_values] = options unless options.empty?
      elsif format == "user"
        params[:multi_value] = jira_field_multi_value?
      end
      params
    end

    def convert_values(custom_field)
      return convert_values_text if format == "text"
      return convert_values_list(custom_field) if format == "list"

      # TODO: convert Jira custom field values to OP custom field values, if needed
      @values
    end

    def custom_field_post_processing(custom_field)
      populate_hierarchy_items(custom_field, values) if format == "hierarchy"
    end

    private

    def convert_values_text
      @values.map { |entry| entry.merge(value: JiraWikiMarkupConverter.new(entry[:value]).convert) }
    end

    def jira_field_multi_value?
      schema = jira_field.payload["schema"] || {}
      schema["type"] == "array" && JIRA_ARRAY_ITEMS_TO_OP_FORMAT.key?(schema["items"])
    end

    def custom_field_by_name(name)
      WorkPackageCustomField.where("LOWER(name) = LOWER(?)", name).first
    end

    def unique_custom_field_name
      unique_name = @import_name
      suffix = 2
      while custom_field_by_name(unique_name)
        unique_name = "#{@import_name} (#{suffix})"
        suffix += 1
      end
      unique_name
    end

    def format
      @format ||= jira_to_op_field_format(jira_field)
    end

    def jira_to_op_field_format(jira_field)
      schema = jira_field.payload["schema"] || {}
      type = schema["type"]
      custom_suffix = schema["custom"].to_s.split(":").last

      if type == "array"
        JIRA_ARRAY_ITEMS_TO_OP_FORMAT.fetch(schema["items"], "string")
      elsif type == "option" && custom_suffix == "cascadingselect"
        EnterpriseToken.allows_to?(:custom_field_hierarchies) ? "hierarchy" : "string"
      else
        JIRA_CUSTOM_SUFFIX_TO_OP_FORMAT[custom_suffix] || JIRA_TYPE_TO_OP_FORMAT.fetch(type, "string")
      end
    end

    def convert_values_list(custom_field)
      @values.map do |v|
        list_value = v[:value]
        list_items = if list_value.is_a?(Array)
                       list_value.map { |c_value| custom_field.value_of(c_value["value"]) }
                     else
                       custom_field.value_of(list_value["value"])
                     end
        v.merge({ value: list_items })
      end
    end

    def collect_list_options(list_values)
      list_values.flat_map do |v|
        list_value = v[:value]
        if list_value.is_a?(Array)
          list_value.map { |c_value| c_value["value"] }
        else
          list_value["value"]
        end
      end
    end

    def populate_hierarchy_items(_custom_field, _values)
      # TODO: populate_hierarchy_items
    end
  end
end
