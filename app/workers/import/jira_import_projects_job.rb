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
  class JiraImportProjectsJob < ApplicationJob
    include Import::JiraOpenProjectReferenceCreation

    # rubocop:disable Metrics/PerceivedComplexity
    # rubocop:disable Metrics/AbcSize
    def perform(jira_import_id)
      jira_import = Import::JiraImport.find(jira_import_id)
      project_ids = jira_import.project_ids
      jira = jira_import.jira
      jira_id = jira.id
      user = User.system
      jira_client = Import::JiraClient.new(url: jira.url, personal_access_token: jira.personal_access_token)

      ActiveRecord::Base.transaction do
        created_projects = []
        created_wps = {}

        service_call = Roles::CreateService.new(user:).call(
          name: "JiraMember",
          permissions: %i[add_work_packages
                          view_work_packages
                          add_work_package_comments
                          add_work_package_attachments
                          work_package_assigned]
        )
        if service_call.success?
          create_reference!(
            op_leg: service_call.result,
            jira_leg: nil,
            jira_import:,
            uses_existing: false
          )
        elsif service_call.errors.find { |error| error.type == :taken }.blank?
          raise service_call.message
        end
        project_role = Role.find_by!(name: "JiraMember")

        Import::JiraProject.where(jira_id:, jira_project_id: project_ids).find_each do |jira_project|
          ### PROJECT
          service_call = Projects::CreateService
                           .new(user:)
                           .call(
                             name: jira_project.payload.fetch("name"),
                             identifier: jira_project.payload.fetch("key").downcase,
                             description: jira_project.payload.fetch("description"),
                             active: true,
                             public: false,
                             parent: nil,
                             status_code: nil,
                             status_explanation: nil,
                             templated: false,
                             workspace_type: "project"
                           )
          project = service_call.result
          if service_call.success?
            created_projects << project
            created_wps[project.id] = []
            create_reference!(
              op_leg: project,
              jira_leg: jira_project,
              jira_import:,
              uses_existing: false
            )
            Import::JiraIssue.where(jira_id:, jira_project_id: jira_project.id).find_each do |jira_issue|
              ### TYPE
              issue_type = jira_issue.payload["fields"]["issuetype"]
              type = Type.where("LOWER(name) = LOWER(?)", issue_type["name"]).first
              uses_existing = true

              if type.blank?
                service_call = WorkPackageTypes::CreateService
                                 .new(user:)
                                 .call(
                                   name: issue_type["name"],
                                   description: issue_type["description"],
                                   is_default: false
                                 )
                if service_call.success?
                  type = service_call.result
                  uses_existing = false
                else
                  raise service_call.message
                end
              end
              service_call = WorkPackageTypes::UpdateService.new(
                user:,
                model: type,
                contract_class: WorkPackageTypes::UpdateProjectsContract
              ).call(
                project_ids: (type.project_ids + [project.id]).tap(&:uniq!).map(&:to_s)
              )
              if service_call.success?
                type = service_call.result
                jira_issue_type = Import::JiraIssueType.find_by!(jira_issue_type_id: issue_type["id"], jira_id:)
                create_reference!(
                  op_leg: type,
                  jira_leg: jira_issue_type,
                  jira_import:,
                  uses_existing:
                )
              else
                raise service_call.message
              end

              ### STATUS
              issue_status = jira_issue.payload["fields"]["status"]
              status = Status.where("LOWER(name) = LOWER(?)", issue_status["name"]).first
              uses_existing = true
              if status.blank?
                status = Status.create!(
                  name: issue_status["name"]
                )
                uses_existing = false
              end
              jira_status = Import::JiraStatus.find_by!(jira_status_id: issue_status["id"], jira_id:)
              create_reference!(
                op_leg: status,
                jira_leg: jira_status,
                jira_import:,
                uses_existing:
              )

              ### PRIORITY
              issue_priority = jira_issue.payload["fields"]["priority"]
              priority = IssuePriority.where("LOWER(name) = LOWER(?)", issue_priority["name"]).first
              uses_existing = true
              if priority.blank?
                priority = IssuePriority.create!(
                  name: issue_priority["name"]
                )
                uses_existing = false
              end
              jira_priority = Import::JiraPriority.find_by!(jira_priority_id: issue_priority["id"], jira_id:)
              create_reference!(
                op_leg: priority,
                jira_leg: jira_priority,
                jira_import:,
                uses_existing:
              )

              ### WORK PACKAGE
              # required because otherwise project.types does not include type and then wp creation fails.
              project.reload
              author_name = jira_issue.payload.dig("fields", "creator", "name")
              author = if author_name.present?
                         User.find_by!(login: author_name)
                       end
              assignee_name = jira_issue.payload.dig("fields", "assignee", "name")
              assigned_to = if assignee_name.present?
                              User.find_by!(login: assignee_name)
                            end
              members = [author, assigned_to]
              members.uniq!
              members.compact!
              members.each do |member|
                add_member(project:, project_role:, member:, user:)
              end

              service_call = WorkPackages::CreateService
                               .new(user: author || User.system)
                               .call(
                                 project:,
                                 subject: jira_issue.payload["fields"]["summary"],
                                 description: convert_rich_text(jira_issue.payload["fields"]["description"]),
                                 type:,
                                 priority:,
                                 status:,
                                 assigned_to:
                               )
              if service_call.success?
                work_package = service_call.result
                created_wps[project.id] << work_package
                create_reference!(
                  op_leg: service_call.result,
                  jira_leg: jira_issue,
                  jira_import:,
                  uses_existing: false
                )

                journal_service = Import::JiraImportJournals.new(work_package:)

                jira_created_at = jira_issue.payload.dig("fields", "created")
                journal_service.update_creation_entry(date_time: jira_created_at) if jira_created_at.present?

                history = jira_issue.payload.dig("changelog", "histories")
                journal_service.add_history(history:) if history.present?

                comments = jira_issue.payload.dig("fields", "comment", "comments") || []
                comments.each do |comment|
                  author = User.find_by!(login: comment["author"]["name"])
                  add_member(project:, project_role:, member: author, user:)
                  journal_service.add_comment(comment:, user: author)
                end

                journal_service.call

                attachments = jira_issue.payload.dig("fields", "attachment") || []
                attachments.each do |attachment|
                  author = User.find_by!(login: attachment["author"]["name"])
                  add_member(project:, project_role:, member: author, user:)
                  add_attachment(jira_client:, work_package:, attachment:, author:)
                end
              else
                raise service_call.message
              end
            end
          else
            raise service_call.message
          end
        end
      end
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/AbcSize

    private

    def convert_rich_text(description)
      return "" if description.blank?

      Import::JiraWikiMarkupConverter.new(description).convert
    end

    # rubocop:disable Metrics/AbcSize
    def add_attachment(jira_client:, work_package:, attachment:, author:)
      filename = attachment["filename"]
      content_url = attachment["content"]
      mime_type = attachment["mimeType"]
      size = attachment["size"]
      response_body = jira_client.download_attachment(content_url)

      Tempfile.create(filename, binmode: true) do |tempfile|
        response_body.copy_to(tempfile)
        tempfile.rewind
        tempfile.define_singleton_method(:original_filename) { filename }
        tempfile.define_singleton_method(:content_type) { mime_type }
        tempfile.define_singleton_method(:size) { size }
        call = Attachments::CreateService
                 .new(user: author)
                 .call(container: work_package, filename:, file: tempfile)

        call.on_failure do
          raise call.message
        end
      end
    end
    # rubocop:enable Metrics/AbcSize

    def add_member(project:, project_role:, member:, user:)
      service_call = Members::CreateService
                       .new(user:)
                       .call(
                         project:,
                         roles: [project_role],
                         user_id: member.id,
                         principal: member
                       )
      return if service_call.success?

      if service_call.errors.find { |error| error.type == :taken }.blank?
        raise service_call.message
      end
    end
  end
end
