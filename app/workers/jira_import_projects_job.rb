class JiraImportProjectsJob < ApplicationJob
  include ::OpenProjectJiraReferenceCreation

  def perform(jira_import_id)
    jira_import  = JiraImport.find(jira_import_id)
    project_ids = jira_import.project_ids
    jira = jira_import.jira
    jira_id = jira.id
    updated_at = Time.now
    created_at = updated_at
    user = User.system
    jira_client = JiraClient.new(url: jira.url, personal_access_token: jira.personal_access_token)
    error = nil

    ActiveRecord::Base.transaction do
      created_projects = []
      created_wps = {}

      service_call = Roles::CreateService.new(user:).call(
        name: "JiraMember",
        permissions: [:add_work_packages,
                      :view_work_packages,
                      :add_work_package_comments,
                      :add_work_package_attachments,
                      :work_package_assigned]
      )
      if service_call.success?
        create_reference!(
          op_leg: service_call.result,
          jira_leg: nil,
          jira_import:,
          uses_existing: false
        )
      else
        if service_call.errors.find { |error| error.type == :taken }.blank?
          raise service_call.message
        end
      end
      project_role = Role.find_by!(name: "JiraMember")

      JiraProject.where(jira_id:, jira_project_id: project_ids).each do |jira_project|
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
          JiraIssue.where(jira_id:, jira_project_id: jira_project.id).each do |jira_issue|
            ### TYPE
            issue_type = jira_issue.payload["fields"]["issuetype"]
            type =  Type.where("LOWER(name) = LOWER(?)", issue_type["name"]).first
            uses_existing = true

            if type.blank?
              service_call = WorkPackageTypes::CreateService
                               .new(user:)
                               .call(
                                 name: issue_type["name"],
                                 description: issue_type["description"],
                                 is_default: false,
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
              jira_issue_type = JiraIssueType.find_by!(jira_issue_type_id: issue_type["id"], jira_id:)
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
                name: issue_status["name"],
              )
              uses_existing = false
            end
            jira_status = JiraStatus.find_by!(jira_status_id: issue_status["id"], jira_id:)
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
                name: issue_priority["name"],
              )
              uses_existing = false
            end
            jira_priority = JiraPriority.find_by!(jira_priority_id: issue_priority["id"], jira_id:)
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
              service_call = Members::CreateService
                               .new(user:)
                               .call(
                                 project:,
                                 roles: [project_role],
                                 user_id: member.id,
                                 principal: member
                               )
              if service_call.success?

              else
                if service_call.errors.find { |error| error.type == :taken }.blank?
                  raise service_call.message
                end
              end
            end

            service_call = WorkPackages::CreateService
              .new(user: author || User.system)
              .call(
                project: project,
                subject: jira_issue.payload["fields"]["summary"],
                description: jira_issue.payload["fields"]["description"],
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

              history = jira_issue.payload["changelog"]["histories"]
              add_history_comment(work_package:, history:, user:) if history.present?

              comments = jira_issue.payload["fields"]["comment"]["comments"]
              comments.each do |comment|
                add_comment(work_package:, comment:)
              end

              attachments = jira_issue.payload["fields"]["attachment"]
              attachments.each do |attachment|
                add_attachment(jira_client:, work_package:, attachment:)
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

  private

  def add_history_comment(work_package:, history:, user:)
    notes = history.map do |entry|
      items = entry["items"]
      author = entry["author"]
      created = entry["created"]
      field_changes = items.map do |item|
        "### Field: #{item['field']}\n\n#### from\n\n#{item['fromString']}\n\n### to\n\n#{item['toString']}"
      end.join("\n\n")
      "## #{author["displayName"]} | #{created}\n\n#{field_changes}"
    end.join("\n\n")
    service_call = AddWorkPackageNoteService
                     .new(user:, work_package: )
                     .call(notes,
                       send_notifications: false,
                       internal: false)

    if service_call.failure?
      raise service_call.message
    end
  end

  def add_comment(work_package:, comment:)
    author = User.find_by!(login: comment["author"]["name"])
    body = comment["body"]
    notes = "## #{author["displayName"]}\n\n ### Comment\n\n#{body}"
    service_call = AddWorkPackageNoteService
                     .new(user: author, work_package: )
                     .call(notes,
                       send_notifications: false,
                       internal: false)

    if service_call.failure?
      raise service_call.message
    end
  end

  def add_attachment(jira_client:, work_package:, attachment:)
    filename = attachment["filename"]
    content_url = attachment["content"]
    author = User.find_by!(login: attachment["author"]["name"])
    created_at = attachment["created"]
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
               .call(container: work_package, filename: filename, file: tempfile)

      call.on_success do
      end

      call.on_failure do
        raise service_call.message
      end
    end
  end
end
