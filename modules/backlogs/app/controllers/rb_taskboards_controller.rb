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

class RbTaskboardsController < RbApplicationController
  menu_item :backlogs

  before_action :load_or_create_board

  def show
    redirect_to project_work_package_board_path(@project, @board)
  end

  private

  def load_or_create_board
    result = TaskBoards::CreateService.ensure(user: current_user, project: @project, sprint: @sprint, name: @sprint.board_name)

    if result.success?
      @board = result.result
    else
      flash[:error] = t(:error_task_board_creation_failed)
      return redirect_back_or_to(backlogs_project_backlogs_path(@project)) # rubocop:disable Style/RedundantReturn
    end
  end
end
