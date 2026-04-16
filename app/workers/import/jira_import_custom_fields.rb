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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Import
  module JiraImportCustomFields
    JIRA_IMPORT_GROUP_KEY = "Jira import"

    def collect_custom_field_attributes(custom_field_registry, jira_issue)
      custom_field_registry.each_with_object({}) do |entry, attrs|
        field_key = entry[:jira_field].jira_field_id
        raw_value = jira_issue.payload["fields"][field_key]
        next if raw_value.blank?

        context = find_context_for_issue(entry, jira_issue)
        next unless context

        custom_field = context[:custom_field]
        attrs[custom_field.attribute_getter] = context[:builder].convert_value(raw_value, custom_field)
      end
    end

    # Builds one OP custom field per (Jira field, context group) combination, before any
    # per-project import begins. Context groups describe which (project_key, issuetype_id)
    # tuples share an allowedValues set.
    def build_custom_field_registry
      jira_field_ids = collect_used_jira_field_ids
      return [] if jira_field_ids.empty?

      Import::JiraField
        .where(jira_id: @jira_id, jira_field_id: jira_field_ids)
        .flat_map { |jira_field| build_registry_entries_for_field(jira_field) }
    end

    def collect_used_jira_field_ids
      used_ids = Set.new
      jira_project_ids = Import::JiraProject
                           .where(jira_id: @jira_id, jira_project_id: @jira_import.project_ids)
                           .pluck(:id)
      Import::JiraIssue.where(jira_id: @jira_id, jira_project_id: jira_project_ids).find_each do |issue|
        issue.payload["fields"].each do |key, value|
          used_ids << key if key.start_with?("customfield_") && value.present?
        end
      end
      used_ids.to_a
    end

    def build_registry_entries_for_field(jira_field)
      if multicheckbox_field?(jira_field)
        build_multicheckbox_registry_entries(jira_field)
      else
        [{ jira_field:, contexts: build_contexts_for_field(jira_field) }]
      end
    end

    def multicheckbox_field?(jira_field)
      schema = jira_field.payload["schema"] || {}
      schema["custom"].to_s.end_with?(":multicheckboxes")
    end

    def build_multicheckbox_registry_entries(jira_field)
      option_values = collect_multicheckbox_option_values(jira_field)
      option_values.map do |option_value|
        { jira_field:, contexts: build_multicheckbox_contexts_for_option(jira_field, option_value) }
      end
    end

    def collect_multicheckbox_option_values(jira_field)
      groups = jira_field.payload["contextGroups"]
      values = if groups.present?
                 groups.flat_map { |g| Array(g["allowedValues"]).pluck("value") }.compact.uniq.sort
               else
                 []
               end
      values.presence || collect_option_values_from_issues(jira_field)
    end

    def all_jira_import_project_ids
      Import::JiraProject
        .where(jira_id: @jira_id, jira_project_id: @jira_import.project_ids)
        .pluck(:id)
    end

    def collect_option_values_from_issues(jira_field)
      values = Set.new
      Import::JiraIssue.where(jira_id: @jira_id, jira_project_id: all_jira_import_project_ids).find_each do |issue|
        raw = issue.payload["fields"][jira_field.jira_field_id]
        next unless raw.is_a?(Array)

        raw.each { |v| values << v["value"] if v["value"].present? }
      end
      values.to_a.sort
    end

    def build_multicheckbox_contexts_for_option(jira_field, option_value)
      groups = jira_field.payload["contextGroups"]
      if groups.present?
        groups.select { |g| Array(g["allowedValues"]).pluck("value").include?(option_value) }
              .map { |group| build_context_entry(jira_field, group, option_value:) }
      else
        [build_context_entry(jira_field, nil, option_value:)]
      end
    end

    def build_contexts_for_field(jira_field)
      groups = jira_field.payload["contextGroups"]
      if groups.present?
        groups.map { |group| build_context_entry(jira_field, group) }
      else
        [build_context_entry(jira_field, nil)]
      end
    end

    def build_context_entry(jira_field, context_group, option_value: nil)
      builder = Import::JiraImportCustomFieldBuilder.new(jira_field, context_group:, option_value:)
      custom_field = find_or_create_custom_field(jira_field, builder)
      {
        projects: Array(context_group&.dig("projects")),
        issuetypes: Array(context_group&.dig("issuetypes")),
        custom_field:,
        builder:
      }
    end

    def find_or_create_custom_field(jira_field, builder)
      existing_cf = builder.find_existing_custom_field
      if existing_cf
        unless Import::JiraOpenProjectReference.exists?(op_entity_id: existing_cf.id,
                                                        op_entity_class: existing_cf.class.to_s,
                                                        jira_id: @jira_id)
          create_reference!(op_leg: existing_cf, jira_leg: jira_field, jira_import: @jira_import, uses_existing: true)
        end
        return existing_cf
      end
      create_custom_field(jira_field, builder)
    end

    def create_custom_field(jira_field, builder)
      name, field_format = builder.custom_field_settings
      params = {
        type: "WorkPackageCustomField",
        name:,
        field_format:,
        is_required: false,
        is_for_all: false,
        **builder.custom_field_parameters
      }
      service_call = CustomFields::CreateService.new(user: @user).call(**params)
      raise "Failed to create custom field '#{jira_field.payload['name']}': #{service_call.message}" unless service_call.success?

      custom_field = service_call.result
      create_reference!(op_leg: custom_field, jira_leg: jira_field, jira_import: @jira_import, uses_existing: false)
      builder.custom_field_post_processing(custom_field)
      custom_field
    end

    # Picks the context entry whose (projects, issuetypes) match the issue's project key and
    # issue type id. Falls back to the first context if none matches - which can happen when
    # editmeta did not see the field for this (project, issuetype) pair but the issue still
    # carries a value for it (e.g. the field was removed from the screen after the value was
    # set). Falling back keeps the value rather than dropping it silently.
    def find_context_for_issue(entry, jira_issue)
      project_key = jira_issue.payload.dig("fields", "project", "key")
      issuetype_id = jira_issue.payload.dig("fields", "issuetype", "id")
      entry[:contexts].find do |ctx|
        context_applies_to_project?(ctx, project_key) && context_applies_to_issuetype?(ctx, issuetype_id)
      end || entry[:contexts].first
    end

    def context_applies_to_project?(context, project_key)
      context[:projects].empty? || context[:projects].include?(project_key)
    end

    def context_applies_to_issuetype?(context, issuetype_id)
      context[:issuetypes].empty? || context[:issuetypes].include?(issuetype_id)
    end
  end
end
