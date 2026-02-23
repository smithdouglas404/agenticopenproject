class JiraImportGroupsAndUsersJob < ApplicationJob
  include JobIteration::Iteration
  include ::OpenProjectJiraReferenceCreation

  on_complete do |job|
    jira_import = JiraImport.find(job.arguments.first)
    jira_import.transition_to!(:groups_and_users_importing_done)
  end

  around_iterate do |job, block|
    block.call
    jira_import = JiraImport.find(job.arguments.first)
    jira_import.update_column(:cursor, cursor_position)
    File.open('progress.txt', 'a') { |f| f.write("cursor: #{cursor_position}\n") }
  end

  rescue_from(StandardError) do |e|
    jira_import = JiraImport.find(arguments.first)
    jira_import.transition_to!(:groups_and_users_importing_error,
                               job_id: self.job_id,
                               error_backtrace: e.backtrace,
                               error: e.message)
  end

  def build_enumerator(jira_import_id, cursor:)
    jira_import = JiraImport.find(jira_import_id)
    File.open('progress.txt', 'a') { |f| f.write("cursor1:#{cursor} --- cursor2:#{jira_import.cursor}\n") }
    cursor ||= (jira_import.cursor.to_i)
    enumerator_builder.active_record_on_records(
      JiraUser.where(jira_import_id:),
      cursor: cursor,
    )
  end

  def each_iteration(jira_user, jira_import_id)
    jira_import = JiraImport.find(jira_import_id)
    call = Users::CreateService
             .new(user: User.system)
             .call(jira_user.to_op_attributes)
    call.on_success do |result|
      create_reference!(
        op_leg: call.result,
        jira_leg: jira_user,
        jira_import:,
        uses_existing: false
      )
    end
    call.on_failure do |result|
      if call.errors.find { |error| error.type == :taken }.present?
        user = jira_user.try_to_find_existing_op_users.first
        if user.present?
          create_reference!(
            op_leg: user,
            jira_leg: jira_user,
            jira_import:,
            uses_existing: true
          )
        else
          raise "Existing User is expected to be found, because there was an email or login collision. See attributes: #{jira_user.to_op_attributes}"
        end
      else
        raise call.message
      end
    end

    jira_user_groups = jira_user.payload["groups"]["items"].map do |item|
      group = item["name"]
    end

    jira_user_groups.each do |group_name|
      call = Groups::CreateService
               .new(user: User.system)
               .call(name: group_name)
      call.on_success do |result|
        group = result.result
        create_reference!(
          op_leg: group,
          jira_leg: nil,
          jira_import:,
          uses_existing: false
        )
      end
      call.on_failure do |result|
        if call.errors.find { |error| error.type == :taken }.present?
          group = Group.where(name: group_name).first
          if group.present?
            create_reference!(
              op_leg: group,
              jira_leg: nil,
              jira_import:,
              uses_existing: true
            )

          else
            raise "Existing Group is expected to be found. Group name: #{group_name}"
          end
        else
          raise call.message
        end
      end
      member_id = OpenProjectJiraReference.where(
        jira_import_id:,
        jira_entity_id: jira_user.id,
        jira_entity_class: jira_user.class.to_s
      ).pluck(:op_entity_id).first
      group = Group.find_by!(name: group_name)
      Groups::AddUsersService
        .new(group, current_user: User.system)
        .call(ids: [member_id], send_notifications: false)
    end
  end
end
