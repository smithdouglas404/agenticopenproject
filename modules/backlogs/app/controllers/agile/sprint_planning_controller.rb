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

module Agile
  class SprintPlanningController < BaseController
    include WorkPackages::WithSplitView

    menu_item :sprint_planning

    skip_before_action :load_sprint
    before_action :load_backlogs, only: :show

    def show
      if turbo_frame_request?
        render partial: "list", layout: false
      else
        render :show
      end
    end

    def details
      if turbo_frame_request?
        render "work_packages/split_view", layout: false
      else
        load_backlogs
        render :show
      end
    end

    def split_view_base_route
      sprint_planning_backlogs_project_backlogs_path(request.query_parameters)
    end

    private

    def load_backlogs
      @owner_backlogs = ::Backlog.owner_backlogs(@project)
      @sprints = ::Agile::Sprint
        .for_project(@project)
        .not_completed
        .order_by_date
      @active_sprint_ids = @sprints.select(&:active?).map(&:id)
    end
  end
end
