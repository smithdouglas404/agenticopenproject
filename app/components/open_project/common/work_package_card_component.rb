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

module OpenProject
  module Common
    class WorkPackageCardComponent < ApplicationComponent
      include OpPrimer::ComponentHelpers
      include ::Backlogs::CommonHelper

      attr_reader :work_package, :project, :container, :current_user

      def initialize(work_package:, project:, container:, current_user: User.current)
        super()

        @work_package = work_package
        @project = project
        @container = container
        @current_user = current_user
      end

      # Threaded into Primer::BorderBox#with_row by the parent box.
      # When DnD migrates to inner-card model (WP #74172), drag-related
      # data attrs leave this hash; row_args shrinks; box loop unchanged.
      def row_args
        {
          id: dom_id(work_package),
          tabindex: 0,
          classes: row_classes,
          data: row_data
        }
      end

      private

      def story_points
        work_package.story_points || 0
      end

      def draggable?
        current_user.allowed_in_project?(:manage_sprint_items, project)
      end

      def split_url
        project_backlogs_backlog_details_path(project, work_package, all_backlogs_params)
      end

      def full_url
        work_package_path(work_package)
      end

      # Sprint is the only positive match; bucket and nil both fall through to inbox.
      def uses_inbox_routes?
        !container.is_a?(Sprint)
      end

      def drop_url
        if uses_inbox_routes?
          move_project_backlogs_inbox_path(project, work_package, all_backlogs_params)
        else
          move_project_backlogs_work_package_path(project, container, work_package, all_backlogs_params)
        end
      end

      def menu_src
        if uses_inbox_routes?
          menu_project_backlogs_inbox_path(project, work_package, all_backlogs_params)
        else
          menu_project_backlogs_work_package_path(project, container, work_package, all_backlogs_params)
        end
      end

      def row_classes
        class_names(
          "Box-row--hover-blue",
          "Box-row--focus-gray",
          "Box-row--clickable",
          "Box-row--draggable" => draggable?
        )
      end

      # `story` data attrs match the live Stimulus controller and Dragula drag-type;
      # renaming requires coordinated JS changes (separate PR).
      def row_data
        base = {
          story: true,
          controller: "backlogs--story",
          backlogs__story_id_value: work_package.id,
          backlogs__story_split_url_value: split_url,
          backlogs__story_full_url_value: full_url,
          backlogs__story_selected_class: "Box-row--blue",
          test_selector: "work-package-#{work_package.id}"
        }

        return base unless draggable?

        base.merge(
          draggable_id: work_package.id,
          draggable_type: "story",
          drop_url:
        )
      end
    end
  end
end
