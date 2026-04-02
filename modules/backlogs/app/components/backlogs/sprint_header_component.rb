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
  class SprintHeaderComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers
    include OpTurbo::Streamable
    include Primer::FetchOrFallbackHelper
    include Redmine::I18n
    include RbCommonHelper

    attr_reader :sprint, :project, :collapsed, :current_user, :active_sprint_ids

    delegate :name, to: :sprint, prefix: :sprint

    def initialize(
      sprint:,
      project:,
      folded: false,
      current_user: User.current,
      active_sprint_ids: nil
    )
      super()

      @sprint = sprint
      @project = project
      @collapsed = folded
      @current_user = current_user
      @active_sprint_ids = active_sprint_ids
    end

    def wrapper_uniq_by
      sprint.id
    end

    def stories
      @sprint.work_packages
    end

    private

    def show_start_sprint_action?
      sprint.in_planning? && ::Sprints::StartContract.can_start?(user: current_user, sprint:, project:)
    end

    def show_finish_sprint_action?
      sprint.active? && ::Sprints::StartContract.can_start_or_finish?(user: current_user, sprint:)
    end

    def disable_start_sprint_action?
      sprint.in_planning? && (!sprint.date_range_set? || project_has_another_active_sprint?)
    end

    def start_sprint_button_arguments
      args = {
        id: dom_target(sprint, :start_button),
        scheme: :invisible
      }

      if disable_start_sprint_action?
        args.merge(tag: :button, inactive: true, aria: { disabled: true })
      else
        args.merge(tag: :a, href: start_project_sprint_path(project, sprint), data: { turbo_method: :post })
      end
    end

    def finish_sprint_button_arguments
      {
        id: dom_target(sprint, :finish_button),
        scheme: :invisible,
        tag: :a,
        href: finish_project_sprint_path(project, sprint),
        data: { turbo_method: :post }
      }
    end

    def story_points
      @story_points ||= stories.sum { |story| story.story_points || 0 }
    end

    def story_count
      @story_count ||= stories.size
    end

    def project_has_another_active_sprint?
      (resolved_active_sprint_ids - [sprint.id]).any?
    end

    def start_sprint_disabled_reason
      return unless disable_start_sprint_action?

      if sprint.date_range_set?
        t(".start_sprint_disabled_reason_active_sprint")
      else
        t(".start_sprint_disabled_reason_missing_dates")
      end
    end

    def resolved_active_sprint_ids
      active_sprint_ids || Agile::Sprint.for_project(sprint.project).active.pluck(:id)
    end
  end
end
