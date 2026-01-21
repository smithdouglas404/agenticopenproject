class J
=begin
curl --request GET \
     --url 'https://jira-software.local/rest/api/2/mypermissions' \
     --header 'Accept: application/json' \
     --header 'Authorization: Bearer <personal_access_token>'

curl --request GET \
     --url 'https://jira-software.local/rest/api/2/search?jql=issuekey=PROCESS1-3' \
     --user 'pavel.balashou:pavel.balashou' \
     --header 'Accept: application/json' \
     --header 'Authorization: Bearer <personal_access_token>'
=end
  def initialize(
        url:,
        personal_access_token:
      )
    @httpx = OpenProject
               .httpx
               .plugin(:basic_auth)
               .with(headers: { "accept" => "application/json" })
               .bearer_auth(personal_access_token)
    @url = url
  end

  # response["permissions"]["SYSTEM_ADMIN"]["havePermission"] == true
  def mypermissions
    @httpx.get("#{@url}/rest/api/2/mypermissions").json
  end

  def index_condition_summary
    @httpx.get("#{@url}/rest/api/2/index/summary").json
  end

  def server_info
    @httpx.get("#{@url}/rest/api/2/serverInfo").json
  end

  def all_cluster_nodes
    @httpx.get("#{@url}/rest/api/2/cluster/nodes").json
  end

  def issues(jql: nil,
             start_at: 0,
             max_results: 100,
             fields: "*all",
             expand: "changelog")
    @httpx.get(
      "#{@url}/rest/api/2/search",
      params: {
        jql:,
        startAt: start_at,
        maxResults: max_results,
        fields:,
        expand:
      }
    ).json
  end

  def issues_count(jql: nil)
    issues(jql:, max_results: 0, fields: "id")["total"]
  end

  def projects(expand = "description,projectKeys")
    @httpx.get("#{@url}/rest/api/2/project", params: { "expand" => expand }).json
  end

  def project_types
    @httpx.get("#{@url}/rest/api/2/project/type").json
  end

  def issue_types
    @httpx.get("#{@url}/rest/api/2/issuetype").json
  end

  def issue_types_count
    response = @httpx.get("#{@url}/rest/api/2/issuetype/page", params: { maxResults: 0 })
    if response.status == 200
      response.json["total"]
    else
      issue_types.count
    end
  end

  def issue_types_schemes
    @httpx.get("#{@url}/rest/api/2/issuetypescheme").json
  end

  def workflows
    @httpx.get("#{@url}/rest/api/2/workflow").json
  end

  def workflowschemes
    @httpx.get("#{@url}/rest/api/2/workflowscheme").json
  end

  def statuses
    @httpx.get("#{@url}/rest/api/2/status").json
  end

  def statuses_count
    response = @httpx.get("#{@url}/rest/api/2/status/search", params: { maxResults: 0 })
    if response.status == 200
      response.json["total"]
    else
      statuses.count
    end
  end

  def status_categories
    @httpx.get("#{@url}/rest/api/2/statuscategory").json
  end

  def permissions
    @httpx.get("#{@url}/rest/api/2/permissions").json
  end

  def permission_schemes
    @httpx.get("#{@url}/rest/api/2/permissionschemes").json
  end

  def priorities
    @httpx.get("#{@url}/rest/api/2/priority").json
  end

  def permission_schemes
    @httpx.get("#{@url}/rest/api/2/priorityschemes").json
  end

  def roles
    @httpx.get("#{@url}/rest/api/2/role").json
  end

  def fields
    @httpx.get("#{@url}/rest/api/2/field").json
  end

  def users_search(username: ".", start_at: 0, max_results: 50)
    @httpx.get("#{@url}/rest/api/2/user/search", params: {
                 "username" => username,
                 startAt: start_at,
                 maxResults: max_results,
                 includeActive: true,
                 includeInactive: true
               }).json
  end

  def user_by_key(key:)
    @httpx.get("#{@url}/rest/api/2/user", params: { key:, expand: "groups" }).json
  end

  def groups(query: ".", start_at: 0, max_results: 50)
    @httpx.get("#{@url}/rest/api/2/groups/picker", params: { query:,  startAt: start_at, maxResults: max_results }).json
  end

  def project_statuses(project_id_or_key)
    @httpx.get("#{@url}/rest/api/2/project/#{project_id_or_key}/statuses").json
  end

  def project(project_id_or_key, expand:, properties:)
    @httpx.get(
      "#{@url}/rest/api/2/project/#{project_id_or_key}", params: {
      expand:,
      properties:
    }).json
  end
end
