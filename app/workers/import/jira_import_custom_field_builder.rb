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
  # Builds OpenProject custom field definition(s) from a Jira custom field
  # and an optional Jira "field context" group.
  class JiraImportCustomFieldBuilder
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

    attr_reader :jira_field, :context_group

    def initialize(jira_field, context_group: nil, option_value: nil)
      @jira_field = jira_field
      @context_group = context_group
      @option_value = option_value
      @import_name = default_import_name
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
      case format
      when "list"
        list_field_parameters
      when "user"
        { multi_value: jira_field_multi_value? }
      else
        {}
      end
    end

    # Converts a single raw Jira field value (as found in `issue.payload["fields"][field_key]`)
    # into the value to assign to the OP custom field attribute.
    def convert_value(raw_value, custom_field)
      case format
      when "bool" then convert_multicheckbox_bool_value(raw_value)
      when "text" then JiraWikiMarkupConverter.new(raw_value.to_s).convert
      when "list" then convert_list_value(raw_value, custom_field)
      else raw_value
      end
    end

    def custom_field_post_processing(custom_field)
      populate_hierarchy_items(custom_field) if format == "hierarchy"
    end

    def format
      @format ||= @option_value ? "bool" : jira_to_op_field_format(jira_field)
    end

    private

    def default_import_name
      base_name = jira_field.payload["name"]
      # Multicheckbox options produce one boolean CF per option - never append
      # project keys since the same option should always map to the same CF.
      return "#{base_name} - #{@option_value}" if @option_value

      project_keys = context_group_projects
      return base_name if project_keys.empty?

      "#{base_name} (#{project_keys.join(', ')})"
    end

    def context_group_projects
      Array(@context_group&.dig("projects"))
    end

    def context_group_allowed_values
      Array(@context_group&.dig("allowedValues"))
    end

    def list_field_parameters
      # In Jira DC, a single custom field can be bound to different allowed-values sets via
      # per-project and per-issuetype Field Contexts. Each distinct option set becomes its
      # own OP custom field, so one `JiraField` can produce several OP CFs. A context group
      # is a hash of the shape:
      #
      #     {
      #       "projects"      => ["DYX", "ABC"],   # Jira project keys sharing this option set
      #       "issuetypes"    => ["10100"],        # Jira issue type ids sharing this option set
      #       "allowedValues" => [{ "value" => "Low" }, ...]
      #     }
      #
      # An empty `projects` / `issuetypes` array means the context applies to all projects /
      # all issue types (used for non-list fields too, where no context discrimination exists).
      params = { multi_value: jira_field_multi_value? }
      options = context_group_allowed_values.pluck("value").compact.uniq
      params[:possible_values] = options if options.any?
      params
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

    def convert_multicheckbox_bool_value(raw_value)
      return false unless raw_value.is_a?(Array)

      raw_value.any? { |v| v["value"] == @option_value }
    end

    def convert_list_value(raw_value, custom_field)
      if raw_value.is_a?(Array)
        raw_value.filter_map { |c_value| custom_field.value_of(c_value["value"]) }
      else
        custom_field.value_of(raw_value["value"])
      end
    end

    def populate_hierarchy_items(_custom_field)
      # TODO: populate_hierarchy_items
    end
  end
end
