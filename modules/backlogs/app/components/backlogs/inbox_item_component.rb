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
  class InboxItemComponent < ApplicationComponent
    include OpPrimer::ComponentHelpers

    attr_reader :work_package, :project, :container, :current_user

    def initialize(inbox_item:, project:, container:, current_user: User.current)
      super()

      @work_package = inbox_item
      @project = project
      @container = container
      @current_user = current_user
    end

    private

    def story_points
      work_package.story_points || 0
    end

    def wrapper_uniq_by
      "inbox-frame-#{project.id}"
    end

    def draggable?
      current_user.allowed_in_project?(:manage_sprint_items, project)
    end

    def row_options
      {
        id: dom_id(work_package),
        classes: row_classes,
        data: {
          story: true,
          controller: row_controllers,
          backlogs__story_id_value: work_package.id,
          backlogs__story_split_url_value: project_backlogs_backlog_details_path(project, work_package),
          backlogs__story_full_url_value: work_package_path(work_package),
          backlogs__story_selected_class: "Box-row--blue",
          test_selector: card_test_selector
        }.merge(draggable_data_attributes),
        tabindex: 0
      }
    end

    def row_classes
      classes = "Box-row--hover-blue Box-row--focus-gray Box-row--clickable"
      classes += " Box-row--draggable" if draggable?
      classes
    end

    def row_controllers
      controllers = ["backlogs--story"]
      controllers.unshift("backlogs--dnd-item") if draggable?

      controllers.join(" ")
    end

    def draggable_data_attributes
      return {} unless draggable?

      {
        backlogs__dnd_item_item_id_value: work_package.id,
        backlogs__dnd_item_item_type_value: "story",
        backlogs__dnd_item_drop_url_value: move_project_backlogs_inbox_path(project, work_package)
      }
    end

    def card_test_selector
      "work-package-#{work_package.id}"
    end
  end
end
