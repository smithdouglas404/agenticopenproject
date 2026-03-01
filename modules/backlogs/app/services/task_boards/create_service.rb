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

class TaskBoards::CreateService
  def self.ensure(user:, project:, name:)
    board = ::Boards::Grid.find_by(project:, name:)
    return ServiceResult.success(result: board) if board

    new(user:).call(project:, name:)
  rescue ActiveRecord::RecordNotUnique
    ServiceResult.success(result: ::Boards::Grid.find_by!(project:, name:))
  end

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  def call(project:, name:)
    create(project:, name:)
  end

  private

  def create(project:, name:)
    ApplicationRecord.transaction do
      statuses = Type.find(Task.type).statuses
      queries  = create_queries(statuses, project:)
      widgets  = build_widgets(queries)

      grid = ::Boards::Grid.create!(
        project:,
        name:,
        options: { "type" => "action", "attribute" => "status", "highlightingMode" => "priority" },
        widgets:,
        column_count: widgets.size,
        row_count: 1
      )
      ServiceResult.success(result: grid)
    end
  rescue ActiveRecord::RecordInvalid => e
    ServiceResult.failure(result: e.record, message: e.message)
  end

  def build_widgets(queries)
    queries.each_with_index.map do |query, i|
      Grids::Widget.new(
        start_row: 1,
        end_row: 2,
        start_column: i + 1,
        end_column: i + 2,
        options: {
          query_id: query.id,
          filters: [{ status: { operator: "=", values: query.filters[0].values } }]
        },
        identifier: "work_package_query"
      )
    end
  end

  def create_queries(statuses, project:)
    statuses.map do |status|
      Query.new_default(project:, user:).tap do |query|
        query.name = status.name
        query.public = true
        query.add_filter("status_id", "=", [status.id])
        query.sort_criteria = [[:manual_sorting, "asc"]]
        query.save!
      end
    end
  end
end
