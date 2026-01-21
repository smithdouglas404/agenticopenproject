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

class JiraInstanceMetaDataJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  good_job_control_concurrency_with(
    total_limit: 2,
    enqueue_limit: 1,
    perform_limit: 1,
    key: -> { "JiraInstanceMetaDataJob-#{arguments.last}" }
  )

  def perform(jira_import_id)
    jira_import = JiraImport.find(jira_import_id)
    get_meta(jira_import)
  end

  def get_meta(jira_import)
    jira = jira_import.jira
    client = J.new(url: jira.url, personal_access_token: jira.personal_access_token)
    available = collect_metadata(client)
    jira_import.update!(status: JiraImport::INSTANCE_META_DONE, job_id: nil, available:, error: nil)
  rescue StandardError => e
    jira_import.update!(status: JiraImport::INSTANCE_META_ERROR, job_id: nil, error: e.message)
  end

  def collect_metadata(client)
    issue_types_count = client.issue_types_count
    statuses_count = client.statuses_count
    issues_count = client.issues_count
    projects = client.projects.map do |project|
      { "id" => project["id"], "key" => project["key"], "name" => project["name"] }
    end
    {
      "projects" => projects,
      "total_issues" => issues_count,
      "total_statuses" => statuses_count,
      "total_issue_types" => issue_types_count
    }
  end
end
