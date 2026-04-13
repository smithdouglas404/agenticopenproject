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
  class SprintComponent < ApplicationComponent
    include Primer::AttributesHelper
    include OpTurbo::Streamable
    include RbCommonHelper

    attr_reader :sprint, :project, :stories, :current_user, :active_sprint_ids

    def initialize(sprint:, project:, stories: nil, current_user: User.current,
                   active_sprint_ids: nil, **system_arguments)
      super()

      @sprint = sprint
      @project = project
      @current_user = current_user
      @active_sprint_ids = active_sprint_ids
      @stories = stories || sprint.work_packages_for(project).includes(:status, :type)

      @system_arguments = system_arguments
      @system_arguments[:id] = dom_id(sprint)
      @system_arguments[:list_id] = "#{@system_arguments[:id]}-list"
      @system_arguments[:padding] = :condensed
      @system_arguments[:data] = merge_data(
        @system_arguments,
        { data: drop_target_config },
        { data: { test_selector: "sprint-#{sprint.id}" } }
      )
    end

    def wrapper_uniq_by
      sprint.id
    end

    private

    def folded?
      current_user.backlogs_preference(:versions_default_fold_state) == "closed"
    end

    def drop_target_config
      {
        generic_drag_and_drop_target: "container",
        target_container_accessor: ":scope > ul",
        target_id: "sprint:#{sprint.id}",
        target_allowed_drag_type: "story"
      }
    end

    def story_classes_attribute
      classes = "Box-row--hover-blue Box-row--focus-gray Box-row--clickable"

      if work_package_draggable?
        classes += " Box-row--draggable"
      end

      classes
    end

    def story_data_attribute(story)
      draggable_item_config(story).merge(
        story: true,
        controller: "backlogs--story",
        backlogs__story_id_value: story.id,
        backlogs__story_split_url_value: details_backlogs_project_backlogs_path(project, story),
        backlogs__story_full_url_value: work_package_path(story),
        backlogs__story_selected_class: "Box-row--blue",
        test_selector: card_test_selector(story)
      )
    end

    def draggable_item_config(story)
      return {} unless work_package_draggable?

      {
        draggable_id: story.id,
        draggable_type: "story",
        drop_url: move_project_sprint_story_path(project, sprint, story)
      }
    end

    def card_test_selector(story)
      "work-package-#{story.id}"
    end

    def work_package_draggable?
      current_user.allowed_in_project?(:manage_sprint_items, project)
    end
  end
end
