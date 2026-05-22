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

module Backlogs
  class BacklogController < BaseController
    include WorkPackages::WithSplitView

    current_menu_item %i[show details] do
      :backlog
    end

    def show
      case turbo_frame_request_id
      when "backlogs_container"
        load_backlogs

        render partial: "backlogs/backlog/backlog_list", layout: false
      else
        render "backlogs/backlog/show"
      end
    end

    def details
      if turbo_frame_request?
        render "work_packages/split_view", layout: false
      else
        load_backlogs

        render "backlogs/backlog/show"
      end
    end

    private

    def split_view_base_route
      project_backlogs_backlog_path(@project, request.query_parameters)
    end

    def load_backlogs
      @backlog_buckets = BacklogBucket.for_project(@project)

      @sprints = Sprint.for_project(@project)
                       .not_completed
                       .order_by_date
                       .includes(:project, :task_boards)
      @active_sprint_ids = @sprints.select(&:active?).map(&:id)

      @work_packages_by_sprint_id = WorkPackage
                                      .where(sprint: @sprints, project: @project)
                                      .order_by_position
                                      .group_by(&:sprint_id)

      # Includes the work packages of both the buckets and the inbox.
      # This has the drawback of loading more work packages than are displayed in the inbox as pagination
      # will only show the top 50 and lowest 10 work packages.
      # But doing only a single query to the database has its benefits, and currently this seems quicker.
      @work_packages_by_backlog_id = WorkPackage
                                       .in_backlog_for(project: @project)
                                       .group_by(&:backlog_bucket_id)
    end
  end
end
