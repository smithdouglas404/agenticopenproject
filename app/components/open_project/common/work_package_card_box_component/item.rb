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
    class WorkPackageCardBoxComponent
      # Internal row bridge between the card box and the visual card. It owns the
      # surrounding BorderBox row arguments while `WorkPackageCardComponent`
      # renders the card body.
      class Item < ApplicationComponent
        include ActionView::RecordIdentifier
        include Primer::ClassNameHelper
        include Primer::AttributesHelper

        attr_reader :work_package,
                    :project,
                    :container,
                    :item_menu_src,
                    :params,
                    :current_user

        def initialize(
          work_package:,
          project:,
          container:,
          params: {},
          item_menu_src: nil,
          current_user: User.current,
          **system_arguments
        )
          super()

          validate_item_menu_src!(item_menu_src)

          @work_package = work_package
          @project = project
          @container = container
          @params = params
          @item_menu_src = item_menu_src
          @current_user = current_user
          @system_arguments = system_arguments
        end

        def row_args
          row_arguments = @system_arguments.deep_dup
          row_arguments[:id] ||= dom_id(work_package)
          row_arguments[:tabindex] ||= 0
          row_arguments[:classes] = class_names(row_classes, row_arguments[:classes])
          row_arguments[:data] = merge_data(
            { data: row_data },
            row_arguments
          )
          row_arguments
        end

        def card
          @card ||= WorkPackageCardComponent.new(work_package:, menu_src: item_menu_src)
        end

        def render? = false

        def empty_item? = false

        private

        def draggable?
          current_user.allowed_in_project?(:manage_sprint_items, project)
        end

        def split_url
          url_helpers.project_backlogs_backlog_details_path(project, work_package, params)
        end

        def full_url
          url_helpers.work_package_path(work_package)
        end

        # Sprint is the only positive match; bucket and inbox both fall through
        # to inbox routes.
        def uses_inbox_routes?
          !container.is_a?(Sprint)
        end

        def drop_url
          if uses_inbox_routes?
            url_helpers.move_project_backlogs_inbox_path(project, work_package, params)
          else
            url_helpers.move_project_backlogs_work_package_path(
              project,
              container,
              work_package,
              params
            )
          end
        end

        def validate_item_menu_src!(source)
          return if source.nil? || source.is_a?(String)

          raise ArgumentError, "item_menu_src must be a String or nil"
        end

        def row_classes
          class_names(
            "Box-row--hover-blue",
            "Box-row--focus-gray",
            "Box-row--clickable",
            "Box-row--draggable" => draggable?
          )
        end

        # `story` data attrs match the live Stimulus controller and Dragula
        # drag-type; renaming requires coordinated JS changes (separate PR).
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
end
