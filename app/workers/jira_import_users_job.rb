class JiraImportUsersJob < ApplicationJob
  include ::OpenProjectJiraReferenceCreation

  def perform(jira_import_id)
    jira_import = JiraImport.find(jira_import_id)
    project_ids = jira_import.project_ids
    jira = jira_import.jira
    jira_id = jira.id
    updated_at = Time.now
    created_at = updated_at
    jira_client = JiraClient.new(url: jira.url, personal_access_token: jira.personal_access_token)

    ActiveRecord::Base.transaction do
      jira_users = JiraUser.where(jira_id: jira.id)
      # group_name => member_ids
      groups = {}
      jira_users.each do |jira_user|
        call = Users::CreateService
                 .new(user: User.system)
                 .call(jira_user.to_op_attributes)
        ref = nil
        call.on_success do |result|
          user_id = call.result.id
          create_reference!(
            op_leg: call.result,
            jira_leg: jira_user,
            jira_import:,
            uses_existing: false
          )
          jira_user
            .payload["groups"]["items"]
            .each do |item|
            group = item["name"]
            groups[group] = Set.new unless groups.key?(group)
            groups[group] << user_id
          end
        end
        call.on_failure do |result|
          if call.errors.find { |error| error.type == :taken }.blank?
            raise call.message
          end
        end
      end
      groups.each do |name, member_ids|
        call = Groups::CreateService
                 .new(user: User.system)
                 .call(name:)
        call.on_success do |result|
          group = result.result
          create_reference!(
            op_leg: group,
            jira_leg: nil,
            jira_import:,
            uses_existing: false
          )

          if member_ids.present?
            add_users_call = Groups::AddUsersService
                               .new(group, current_user: User.system)
                               .call(ids: member_ids, send_notifications: false)
          end
        end
        call.on_failure do |result|
          if call.errors.find { |error| error.type == :taken }.blank?
            raise call.message
          end
        end
      end
    end
  end
end
