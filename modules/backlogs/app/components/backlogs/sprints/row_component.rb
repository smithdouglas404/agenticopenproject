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
  module Sprints
    class RowComponent < ::OpPrimer::BorderBoxRowComponent
      delegate :project, to: :table

      def sprint
        model
      end

      def name
        if href_for_sprint
          render(Primer::Beta::Link.new(href: href_for_sprint, font_weight: :bold)) { sprint.name }
        else
          sprint.name
        end
      end

      def status
        render(SprintStatusBadgeComponent.new(sprint:))
      end

      def start_date
        helpers.format_date(sprint.start_date) if sprint.start_date
      end

      def finish_date
        helpers.format_date(sprint.finish_date) if sprint.finish_date
      end

      def work_package_count
        table.work_package_counts.fetch(sprint.id, 0)
      end

      def row_css_id
        dom_id(sprint)
      end

      private

      def href_for_sprint
        return @href_for_sprint if defined?(@href_for_sprint)

        @href_for_sprint = if sprint.active?
                             project_work_package_board_path(project, sprint.task_board_for(project))
                           elsif sprint.in_planning?
                             project_backlogs_backlog_path(project)
                           elsif sprint.completed?
                             link_to_work_packages_table
                           end
      end

      def link_to_work_packages_table
        default_columns = Setting.work_package_list_default_columns.map(&:to_s)

        project_work_packages_path(
          project,
          query_props: {
            f: [{ n: "sprintId", o: "=", v: [sprint.id.to_s] }],
            t: "position:asc",
            c: default_columns | ["sprint"]
          }.to_json
        )
      end
    end
  end
end
