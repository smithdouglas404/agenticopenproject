class JiraFetchUsersJob < ApplicationJob
  def perform(jira_import_id)
    jira_import  = JiraImport.find(jira_import_id)
    project_ids = jira_import.projects
    jira = jira_import.jira
    jira_id = jira.id
    updated_at = Time.now
    created_at = updated_at
    j = J.new(url: jira.url, personal_access_token: jira.personal_access_token)

    start_at = 0
    max_results = 1 # It should be 1000 to reduce the number of requests
    jira_users = j.users_search(start_at: , max_results: )
    users_upsert_data = jira_users.map do |jira_user_from_search|
      jira_user_key = jira_user_from_search.fetch('key')
      # here we send a direct user request to get group memberships
      # which are not returned by users_search endpoint
      jira_user_by_key = j.user_by_key(key: jira_user_key)
      {
        payload: jira_user_by_key,
        jira_id: jira_id,
        jira_import_id: jira_import.id,
        jira_user_key: ,
        created_at:,
        updated_at:
      }
    end
    upsert_result = JiraUser.upsert_all(users_upsert_data, unique_by: [:jira_id, :jira_user_key])

    while(jira_users.any?)
      start_at = start_at + jira_users.count
      jira_users = j.users_search(start_at: , max_results: )
      users_upsert_data = jira_users.map do |jira_user_from_search|
        jira_user_key = jira_user_from_search.fetch('key')
        # here we send a direct user request to get group memberships
        # which are not returned by users_search endpoint
        jira_user_by_key = j.user_by_key(key: jira_user_key)
        {
          payload: jira_user_by_key,
          jira_id: jira_id,
          jira_import_id: jira_import.id,
          jira_user_key:,
          created_at:,
          updated_at:
        }
      end
      upsert_result = JiraUser.upsert_all(users_upsert_data, unique_by: [:jira_id, :jira_user_key])
    end
  end
end
