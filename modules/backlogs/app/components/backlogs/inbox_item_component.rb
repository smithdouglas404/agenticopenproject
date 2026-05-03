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
    include CommonHelper

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
        data: row_data,
        tabindex: 0
      }
    end

    def row_classes
      class_names(
        "Box-row--hover-blue",
        "Box-row--focus-gray",
        "Box-row--clickable",
        "Box-row--draggable": draggable?
      )
    end

    def row_data
      draggable_item_config.merge(
        story: true,
        controller: "backlogs--story",
        backlogs__story_id_value: work_package.id,
        backlogs__story_display_id_value: work_package.display_id,
        backlogs__story_split_url_value: split_url,
        backlogs__story_full_url_value: full_url,
        backlogs__story_selected_class: "Box-row--blue",
        test_selector: card_test_selector
      )
    end

    def draggable_item_config
      return {} unless draggable?

      {
        draggable_id: work_package.id,
        draggable_type: "story",
        drop_url:
      }
    end

    def drop_url
      move_project_backlogs_inbox_path(project, work_package, all_backlogs_params)
    end

    def split_url
      project_backlogs_backlog_details_path(project, work_package, all_backlogs_params)
    end

    def full_url
      work_package_path(work_package)
    end

    def card_test_selector
      "work-package-#{work_package.id}"
    end
  end
end
