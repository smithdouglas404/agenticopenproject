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

class RbMasterBacklogsController < RbApplicationController
  include WorkPackages::WithSplitView

  current_menu_item [:backlog, :details] do
    :backlog
  end

  before_action :load_backlogs, only: %i[index backlog]

  def backlog
    case turbo_frame_request_id
    when "backlogs_container"
      render partial: "backlog_list", layout: false
    else
      render :backlog
    end
  end

  def index
    redirect_to action: :backlog
  end

  def details
    if turbo_frame_request?
      render "work_packages/split_view", layout: false
    else
      load_backlogs
      render :backlog
    end
  end

  private

  def split_view_base_route
    backlog_backlogs_project_backlogs_path(request.query_parameters)
  end

  def load_backlogs
    @sprints = Agile::Sprint.for_project(@project).not_completed.order_by_date
    @stories_by_sprint_id = WorkPackage
      .where(sprint: @sprints, project: @project)
      .includes(:type, :status)
      .order_by_position
      .group_by(&:sprint_id)
    @active_sprint_ids = @sprints.select(&:active?).map(&:id)
    @inbox_work_packages = Backlog.inbox_for(project: @project)
  end
end
