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

module OpenProject::Backlogs
  class WorkPackageSprintSelect < Queries::WorkPackages::Selects::WorkPackageSelect
    SORT_ORDER = %w[visible_sprints.name
                    visible_sprints.start_date
                    visible_sprints.finish_date].freeze

    def initialize
      # Cannot use `association` here since that will break our custom GROUP BY
      super(:sprint,
            sortable: SORT_ORDER,
            groupable_join: sprint_join_with_permissions,
            groupable: group_by_statement,
            groupable_select: groupable_select)
    end

    def self.instances(context = nil)
      return [] if context && !context.backlogs_enabled?
      return [] unless OpenProject::FeatureDecisions.scrum_projects_active?
      return [] unless user_allowed_to_select_sprint?(context)

      [new]
    end

    def self.user_allowed_to_select_sprint?(context)
      if context
        User.current.allowed_in_project?(:view_sprints, context)
      else
        User.current.allowed_in_any_project?(:view_sprints)
      end
    end

    def sortable_join_statement(_query)
      sprint_join_with_permissions
    end

    def groupable_select
      group_by_statement
    end

    def group_by_statement
      "visible_sprints.id"
    end

    private

    def sprint_join_with_permissions
      <<~SQL.squish
        LEFT OUTER JOIN "projects" ON "projects"."id" = "work_packages"."project_id"
        LEFT OUTER JOIN (
          SELECT
            s.id,
            s.name,
            s.start_date,
            s.finish_date,
            s.project_id
          FROM sprints s
          WHERE s.project_id IN (#{projects_with_view_sprints_permissions.to_sql})
        ) AS visible_sprints
        ON visible_sprints.id = work_packages.sprint_id
          AND visible_sprints.project_id = work_packages.project_id
      SQL
    end

    def projects_with_view_sprints_permissions
      Project.allowed_to(User.current, :view_sprints).select(:id)
    end
  end
end
