class JiraMetaDataJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency
  good_job_control_concurrency_with(
    total_limit: 2,
    enqueue_limit: 1,
    perform_limit: 1,
    key: -> { "JiraMetaDataJob-#{arguments.last}" }
  )

  def perform(jira_import_id)
    jira_import = JiraImport.find(jira_import_id)
    get_meta(jira_import)
  end

  def get_meta(jira_import)
    jira = jira_import.jira
    j = J.new(url: jira.url, personal_access_token: jira.personal_access_token)
    available = collect_metadata(j)
    jira_import.update!(status: "fetched", job_id: nil, available:)
  rescue StandardError => e
    jira_import.update!(status: "fetch-error", job_id: nil, error: e.message)
  end

  def collect_metadata(j)
    projects = j.projects
    issue_types = j.issue_types
    statuses = j.statuses

    project_stats = projects.map do |project|
      result = j.issues(jql: "project = '#{project["key"]}'", max_results: 0)
      {
        "id" => project["id"],
        "key" => project["key"],
        "name" => project["name"],
        "issue_count" => result["total"]
      }
    end

    total_issues = project_stats.sum { |p| p["issue_count"] }

    {
      "projects" => project_stats,
      "total_issues" => total_issues,
      "total_statuses" => statuses.count,
      "total_issue_types" => issue_types.count,
      "total_users" => nil
    }
  end
end
