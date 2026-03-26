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
  class SprintMenuComponent < ApplicationComponent
    include RbCommonHelper

    attr_reader :sprint, :project, :current_user, :active_sprint_ids

    def initialize(sprint:, project:, current_user: User.current, active_sprint_ids: nil, **system_arguments)
      super()

      @sprint = sprint
      @project = project
      @current_user = current_user
      @active_sprint_ids = active_sprint_ids

      @system_arguments = system_arguments
      @system_arguments[:menu_id] = dom_target(sprint, :menu)
      @system_arguments[:anchor_align] = :end
      @system_arguments[:classes] = class_names(
        @system_arguments[:classes],
        "hide-when-print"
      )
    end

    def stories
      @sprint.work_packages
    end

    private

    def show_task_board_link?
      sprint.task_board_for(project).present?
    end

    def show_start_sprint_action?
      sprint.in_planning? && ::Sprints::StartContract.can_start?(user: current_user, sprint:, project:)
    end

    def show_finish_sprint_action?
      sprint.active? && ::Sprints::StartContract.can_start_or_finish?(user: current_user, sprint:)
    end

    def disable_start_sprint_action?
      sprint.in_planning? && (!sprint.date_range_set? || project_has_another_active_sprint?)
    end

    def start_sprint_action_description
      return unless disable_start_sprint_action?

      if sprint.date_range_set?
        t(".action_menu.start_sprint_disabled_description")
      else
        t(".action_menu.start_sprint_missing_dates_description")
      end
    end

    def user_allowed?(permission)
      current_user.allowed_in_project?(permission, project)
    end

    def available_story_types
      @available_story_types ||= story_types & project.types
    end

    def project_has_another_active_sprint?
      (resolved_active_sprint_ids - [sprint.id]).any?
    end

    def resolved_active_sprint_ids
      active_sprint_ids || Agile::Sprint.for_project(sprint.project).active.pluck(:id)
    end
  end
end
