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
  class JiraFetchProjectsJob < ApplicationJob
    # rubocop:disable Metrics/AbcSize
    def perform(jira_import_id)
      jira_import = Import::JiraImport.find(jira_import_id)
      project_ids = jira_import.project_ids
      jira = jira_import.jira
      jira_id = jira.id
      updated_at = Time.zone.now
      created_at = updated_at
      jira_client = Import::JiraClient.new(url: jira.url, personal_access_token: jira.personal_access_token)

      # ISSUE TYPES SYNC
      issue_types = jira_client.issue_types
      issue_types_upsert_data = issue_types.map do |issue_type|
        {
          payload: issue_type,
          jira_id:,
          jira_issue_type_id: issue_type.fetch("id"),
          jira_import_id: jira_import.id,
          created_at:,
          updated_at:
        }
      end
      Import::JiraIssueType.upsert_all(issue_types_upsert_data, unique_by: %i[jira_id jira_issue_type_id])

      # PRIORITIES SYNC
      priorities = jira_client.priorities
      priorities_upsert_data = priorities.map do |priority|
        {
          payload: priority,
          jira_id:,
          jira_priority_id: priority.fetch("id"),
          jira_import_id: jira_import.id,
          created_at:,
          updated_at:
        }
      end
      Import::JiraPriority.upsert_all(priorities_upsert_data, unique_by: %i[jira_id jira_priority_id])

      # STATUSES SYNC
      statuses = jira_client.statuses
      statuses_upsert_data = statuses.map do |status|
        {
          payload: status,
          jira_id:,
          jira_status_id: status.fetch("id"),
          jira_import_id: jira_import.id,
          created_at:,
          updated_at:
        }
      end
      Import::JiraStatus.upsert_all(statuses_upsert_data, unique_by: %i[jira_id jira_status_id])

      # PROJECTS SYNC
      projects_upsert_data = jira_client.projects.map do |p|
        {
          payload: p,
          jira_id:,
          jira_project_id: p.fetch("id"),
          jira_import_id: jira_import.id,
          created_at:,
          updated_at:
        }
      end
      Import::JiraProject.upsert_all(projects_upsert_data, unique_by: %i[jira_id jira_project_id])

      # ISSUES SYNC
      Import::JiraProject.where(jira_id:, jira_project_id: project_ids).find_each do |jira_project|
        jql = "project=#{jira_project.payload['key']}"
        result = jira_client.issues(jql:,
                                    start_at: 0,
                                    max_results: 5)
        total = result["total"]
        start_at = result["startAt"]
        max_results = result["maxResults"]
        issues_upsert_data = result["issues"].map do |issue|
          {
            payload: issue,
            jira_id:,
            jira_project_id: jira_project.id,
            jira_issue_id: issue.fetch("id"),
            jira_import_id: jira_import.id,
            created_at:,
            updated_at:
          }
        end
        Import::JiraIssue.upsert_all(issues_upsert_data, unique_by: %i[jira_id jira_issue_id])
        while total > start_at + max_results
          start_at += max_results
          result = jira_client.issues(jql:,
                                      start_at:,
                                      max_results: 5)
          total = result["total"]
          start_at = result["startAt"]
          max_results = result["maxResults"]
          issues_upsert_data = result["issues"].map do |issue|
            {
              payload: issue,
              jira_id:,
              jira_project_id: jira_project.id,
              jira_issue_id: issue.fetch("id"),
              jira_import_id: jira_import.id,
              created_at:,
              updated_at:
            }
          end
          Import::JiraIssue.upsert_all(issues_upsert_data, unique_by: %i[jira_id jira_issue_id])
        end
      end
    end
    # rubocop:enable Metrics/AbcSize
  end
end
