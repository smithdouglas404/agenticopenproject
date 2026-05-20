# frozen_string_literal: true

# -- copyright
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
# ++

module WorkPackages::Scopes::WithBacklogsNeighbours
  extend ActiveSupport::Concern

  class_methods do
    def with_backlogs_neighbours
      # The subquery is required because window functions run before WHERE clauses.
      # Chaining .find(id) directly would filter rows first, leaving the window function
      # with a single row and returning nil for all neighbours. Wrapping in a subquery
      # lets the window function see the full scope, then the outer query filters to the
      # requested record.
      subquery = order_by_position.select(
        "*, LAG(id)    OVER (ORDER BY position) AS prev_id,
            LAG(id, 2) OVER (ORDER BY position) AS prev_prev_id,
            LEAD(id)   OVER (ORDER BY position) AS next_id"
      )
      WorkPackage.from(subquery, :work_packages)
    end
  end
end
