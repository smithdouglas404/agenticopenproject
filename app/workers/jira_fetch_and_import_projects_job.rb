class JiraFetchAndImportProjectsJob < ApplicationJob
  def perform(jira_import_id)
    jira_import = JiraImport.find(jira_import_id)
    JiraFetchUsersJob.perform_now(jira_import_id)
    JiraImportUsersJob.perform_now(jira_import_id)
    JiraFetchProjectsJob.perform_now(jira_import_id)
    JiraImportProjectsJob.perform_now(jira_import_id)

    jira_import.update!(status: JiraImport::IMPORTED, job_id: nil)
  rescue StandardError => e
    jira_import.update!(status: JiraImport::IMPORT_ERROR, job_id: nil, error: e.message)
  end
end
