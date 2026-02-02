class JiraRevertJiraImportJob < ApplicationJob
  def perform(jira_import_id)
    jira_import  = JiraImport.find(jira_import_id)
    project_ids = jira_import.projects
    jira = jira_import.jira
    jira_id = jira.id
    user = User.system

    ActiveRecord::Base.transaction do
      OpenProjectJiraReference
        .where(jira_import_id: jira_import.id,)
        .where.not(op_entity_class: "WorkPackage")
        .find_each do |ref|
        op_leg = ref.op_leg
        uses_existing = ref.uses_existing
        if op_leg.is_a? Project
          service_call = ::Projects::DeleteService.new(user:, model: op_leg).call
          if service_call.failure?
            raise ActiveRecord::Rollback
          end
        elsif op_leg.is_a? WorkPackage
          # removed with project
        elsif op_leg.is_a? Type
          op_leg.destroy unless uses_existing
        elsif op_leg.is_a? Status
          op_leg.destroy unless uses_existing
        elsif op_leg.is_a? IssuePriority
          op_leg.destroy unless uses_existing
        end
      end
      OpenProjectJiraReference
        .where(jira_import_id: jira_import.id,)
        .where(op_entity_class: "User")
        .find_each do |ref|
        op_leg = ref.op_leg
        uses_existing = ref.uses_existing
        # EmptyContract is used to make deletion not dependent on Setting.users_deletable_by_admins
        service_call = ::Users::DeleteService.new(user:, model: op_leg, contract_class: EmptyContract).call
        if service_call.failure?
          raise ActiveRecord::Rollback
        end
      end
      OpenProjectJiraReference
        .where(jira_import_id: jira_import.id,)
        .where(op_entity_class: "Group")
        .find_each do |ref|
        op_leg = ref.op_leg
        uses_existing = ref.uses_existing
        service_call = ::Groups::DeleteService.new(user:, model: op_leg).call
        if service_call.failure?
          raise ActiveRecord::Rollback
        end
      end
      OpenProjectJiraReference
        .where(jira_import_id: jira_import.id,)
        .where(op_entity_class: "ProjectRole")
        .find_each do |ref|
        op_leg = ref.op_leg
        uses_existing = ref.uses_existing
        service_call = ::Roles::DeleteService.new(user:, model: op_leg).call
        if service_call.failure?
          raise ActiveRecord::Rollback
        end
      end

      OpenProjectJiraReference.where(jira_import_id: jira_import.id).delete_all

      jira_import.update!(status: JiraImport::REVERTED, job_id: nil)
    end
  rescue StandardError => e
    jira_import.update!(status: JiraImport::REVERT_ERROR, job_id: nil, error: e.message)
  end
end
