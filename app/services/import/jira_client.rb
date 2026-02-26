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
  class JiraClient
    class Error < StandardError; end

    class ConnectionError < Error; end

    class ParseError < Error; end

    class ApiError < Error
      attr_reader :status, :response_body

      def initialize(message, status: nil, response_body: nil)
        super(message)
        @status = status
        @response_body = response_body
      end
    end

    def initialize(url:, personal_access_token:)
      raise ApiError.new(I18n.t(:"admin.jira.test.token_error")) if personal_access_token.nil?

      @httpx = OpenProject
                 .httpx
                 .plugin(:auth)
                 .bearer_auth(personal_access_token)
                 .with(
                   headers: { "accept" => "application/json" },
                   timeout: {
                     connect_timeout: 30,
                     operation_timeout: 30,
                     request_timeout: 30,
                     read_timeout: 30
                   }
                 )
      @url = url.chomp("/")
    end

    def mypermissions
      get("/rest/api/2/mypermissions")
    end

    def index_condition_summary
      get("/rest/api/2/index/summary")
    end

    def server_info
      get("/rest/api/2/serverInfo")
    end

    def all_cluster_nodes
      get("/rest/api/2/cluster/nodes")
    end

    def issues(jql: nil, start_at: 0, max_results: 100, fields: "*all", expand: "changelog")
      get("/rest/api/2/search", params:
        {
          jql:,
          startAt: start_at,
          maxResults: max_results,
          fields:,
          expand:
        })
    end

    def issues_count(jql: nil)
      issues(jql:, max_results: 0, fields: "id")["total"]
    end

    def projects(expand = "description,projectKeys")
      get("/rest/api/2/project", params: { "expand" => expand })
    end

    def project_types
      get("/rest/api/2/project/type")
    end

    def issue_types
      get("/rest/api/2/issuetype")
    end

    def issue_types_count
      response = get_response("/rest/api/2/issuetype/page", params: { maxResults: 0 })
      if response.status == 200
        parse_json(response)["total"]
      else
        issue_types.count
      end
    end

    def issue_types_schemes
      get("/rest/api/2/issuetypescheme")
    end

    def workflows
      get("/rest/api/2/workflow")
    end

    def workflowschemes
      get("/rest/api/2/workflowscheme")
    end

    def statuses
      get("/rest/api/2/status")
    end

    def statuses_count
      response = get_response("/rest/api/2/status/search", params: { maxResults: 0 })
      if response.status == 200
        parse_json(response)["total"]
      else
        statuses.count
      end
    end

    def status_categories
      get("/rest/api/2/statuscategory")
    end

    def permissions
      get("/rest/api/2/permissions")
    end

    def permission_schemes
      get("/rest/api/2/permissionschemes")
    end

    def priorities
      get("/rest/api/2/priority")
    end

    def priority_schemes
      get("/rest/api/2/priorityschemes")
    end

    def roles
      get("/rest/api/2/role")
    end

    def fields
      get("/rest/api/2/field")
    end

    def users_search(username: ".", start_at: 0, max_results: 50)
      get("/rest/api/2/user/search", params:
        {
          username:,
          startAt: start_at,
          maxResults: max_results,
          includeActive: true,
          includeInactive: true
        })
    end

    def user_by_key(key:)
      get("/rest/api/2/user", params: { key:, expand: "groups" })
    end

    def groups(query: "", max_results: 1000)
      get("/rest/api/2/groups/picker", params: { query:, maxResults: max_results })
    end

    def group_members(group_name: "jira-software-users", start_at: 0, max_results: 500)
      get("/rest/api/2/group/member", params: { groupname: group_name, startAt: start_at, maxResults: max_results })
    end

    def project_statuses(project_id_or_key)
      get("/rest/api/2/project/#{project_id_or_key}/statuses")
    end

    def project(project_id_or_key, expand:, properties:)
      get("/rest/api/2/project/#{project_id_or_key}", params:
        {
          expand:,
          properties:
        })
    end

    def download_attachment(content_url)
      case (response = @httpx.get(content_url))
      in { status: 200..299 }
        response.body
      in { status: 300..399 }
        case (redirect_response = @httpx.get(response.headers["location"]))
        in { status: 200..299 }
          redirect_response.body
        in { status: 300.. }
          raise "BAD RESPONSE: #{redirect_response.status}, #{redirect_response.body}"
        in { error: error }
          raise error
        end
      in { status: 400.. }
        raise "BAD RESPONSE: #{response}"
      in { error: error }
        raise error
      end
    end

    private

    def get(path, params: {})
      response = get_response(path, params:)
      handle_response(response)
    end

    def get_response(path, params: {})
      response = @httpx.get("#{@url}#{path}", params:)

      if response.is_a?(HTTPX::ErrorResponse)
        raise ConnectionError, I18n.t("admin.jira.client.connection_error", message: response.error.message)
      end

      response
    rescue HTTPX::ConnectionError, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      raise ConnectionError, I18n.t("admin.jira.client.connection_error", message: e.message)
    rescue Timeout::Error => e
      raise ConnectionError, I18n.t("admin.jira.client.connection_timeout", message: e.message)
    end

    def handle_response(response)
      if response.status >= 200 && response.status < 300
        parse_json(response)
      else
        raise ApiError.new(
          I18n.t("admin.jira.client.api_error", status: response.status),
          status: response.status,
          response_body: response.body.to_s
        )
      end
    end

    def parse_json(response)
      response.json
    rescue JSON::ParserError, HTTPX::Error => e
      raise ParseError, I18n.t("admin.jira.client.parse_error", message: e.message)
    end
  end
end
