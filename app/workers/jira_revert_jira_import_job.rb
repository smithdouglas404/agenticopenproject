class JiraRevertJiraImportJob < ApplicationJob
  include JobIteration::Iteration
  REVERT_STEPS = %i(delete_projects
                    delete_types_statuses_and_issue_priorities
                    delete_users
                    delete_groups
                    delete_project_roles
                    delete_references)

      # def on_start(*filters, &blk)
      #   set_callback(:start, :after, *filters, &blk)
      # end

      # def on_shutdown(*filters, &blk)
      #   set_callback(:shutdown, :after, *filters, &blk)
      # end

      # def on_complete(*filters, &blk)
      #   set_callback(:complete, :after, *filters, &blk)
      # end

      # def around_iterate(&blk)
      #   set_callback(:iterate, :around, &blk)
      # end


  def build_enumerator(jira_import_id, cursor:)
    @jira_import = JiraImport.find(jira_import_id)
    File.open('progress.txt', 'a') { |f| f.write("cursor1:#{cursor} --- cursor2:#{REVERT_STEPS.index(@jira_import.cursor&.to_sym)}\n") }
    cursor ||= REVERT_STEPS.index(@jira_import.cursor&.to_sym)
    enumerator_builder.array(REVERT_STEPS, cursor: cursor)
  rescue StandardError => e
    @jira_import.transition_to!(:revert_error,
                                job_id: self.job_id,
                                error_backtrace: e.backtrace,
                                error: e.message)
  end

  def each_iteration(revert_step, jira_import_id)
    @jira_import  = JiraImport.find(jira_import_id)
    @user = User.system
    ApplicationRecord.transaction do
      send(revert_step)
    end
    @jira_import.update_column(:cursor, revert_step)
    File.open('progress.txt', 'a') { |f| f.write("#{self.class}:#{self.job_id}:#{revert_step}\n") }
  rescue StandardError => e
    binding.pry
    @jira_import.transition_to!(:revert_error,
                                job_id: self.job_id,
                                error_backtrace: e.backtrace,
                                error: e.message,
                                revert_step:)
    throw(:abort)
  end

  private

  def job_should_exit?
    if @jira_import.reload.in_state?(:revert_cancelling)
      @jira_import.transition_to!(:revert_cancelled)
      throw(:abort)
    end
    super
  end

  def delete_projects
    OpenProjectJiraReference
      .where(jira_import_id: @jira_import.id,)
      .where(op_entity_class: "Project")
      .find_each do |ref|
      op_leg = ref.op_leg
      uses_existing = ref.uses_existing
      service_call = ::Projects::DeleteService.new(user: @user, model: op_leg).call
      if service_call.failure?
        raise service_call.message
      end
    end
  end

  def delete_types_statuses_and_issue_priorities
    OpenProjectJiraReference
      .where(jira_import_id: @jira_import.id,)
      .where(op_entity_class: ["Type", "IssuePriority", "Status"])
      .find_each do |ref|
      op_leg = ref.op_leg
      uses_existing = ref.uses_existing
      op_leg.destroy! unless uses_existing
    end
  end

  def delete_users
    OpenProjectJiraReference
      .where(jira_import_id: @jira_import.id,)
      .where(op_entity_class: "User")
      .find_each do |ref|
      op_leg = ref.op_leg
      uses_existing = ref.uses_existing
      # EmptyContract is used to make deletion not dependent on Setting.users_deletable_by_admins
      service_call = ::Users::DeleteService.new(user: @user, model: op_leg, contract_class: EmptyContract).call
      if service_call.failure?
        raise service_call.message
      end
    end
  end

  def delete_groups
    OpenProjectJiraReference
      .where(jira_import_id: @jira_import.id,)
      .where(op_entity_class: "Group")
      .find_each do |ref|
      op_leg = ref.op_leg
      uses_existing = ref.uses_existing
      service_call = ::Groups::DeleteService.new(user: @user, model: op_leg).call
      if service_call.failure?
        raise service_call.message
      end
    end
  end

  def delete_project_roles
    OpenProjectJiraReference
      .where(jira_import_id: @jira_import.id,)
      .where(op_entity_class: "ProjectRole")
      .find_each do |ref|
      op_leg = ref.op_leg
      uses_existing = ref.uses_existing
      service_call = ::Roles::DeleteService.new(user: @user, model: op_leg).call
      if service_call.failure?
        raise service_call.message
      end
    end
  end

  def delete_references
    OpenProjectJiraReference.where(jira_import_id: @jira_import.id).delete_all
    @jira_import.transition_to!(:reverted, job_id: self.job_id)
  end
end
