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

  # Without the feature flag, there is only the top level menu item, select it
  menu_item :backlogs_legacy, only: :index

  # With the feature flag, we have a proper menu, select the correct sub entry
  menu_item :backlog, only: %i[backlog details]

  before_action :not_authorized_on_feature_flag_inactive, only: :backlog
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
    return redirect_to action: :backlog if OpenProject::FeatureDecisions.scrum_projects_active?

    case turbo_frame_request_id
    when "backlogs_container"
      render partial: "list", layout: false
    else
      render :index
    end
  end

  def details
    if turbo_frame_request?
      render "work_packages/split_view", layout: false
    else
      load_backlogs

      if OpenProject::FeatureDecisions.scrum_projects_active?
        render :backlog
      else
        render :index
      end
    end
  end

  private

  def split_view_base_route
    if OpenProject::FeatureDecisions.scrum_projects_active?
      backlog_backlogs_project_backlogs_path(request.query_parameters)
    else
      backlogs_project_backlogs_path(request.query_parameters)
    end
  end

  def load_backlogs
    @owner_backlogs = Backlog.owner_backlogs(@project)

    if OpenProject::FeatureDecisions.scrum_projects_active?
      @sprints = Agile::Sprint.displayable_in_project(@project)
      @stories_by_sprint_id = WorkPackage
        .where(sprint: @sprints, project: @project)
        .includes(:type, :status)
        .order_by_position
        .group_by(&:sprint_id)
      @active_sprint_ids = @sprints.select(&:active?).map(&:id)
      @inbox_work_packages = Backlog.inbox_for(project: @project)
    else
      @sprint_backlogs = Backlog.sprint_backlogs(@project)
    end
  end
end
