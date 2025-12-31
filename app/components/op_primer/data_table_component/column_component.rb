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

module OpPrimer
  class DataTableComponent::ColumnComponent < Primer::Component
    COLUMN_WIDTH_OPTIONS = %i[grow grow_collapse auto].freeze

    attr_reader :id, :align, :field, :max_width, :min_width, :row_header, :sort_by, :width, :cell_block

    renders_one :header, -> {
      Primer::Content.new
    }

    def with_cell(&block)
      @cell_block = block
    end

    # @param align The horizontal alignment of the column's content
    # @param header Provide the name of the column. This will be rendered as a table header within the table itself
    def initialize( # rubocop:disable Lint/MissingSuper
      id: nil,
      field: nil,
      align: OpPrimer::TableComponent::CellComponent::DEFAULT_ALIGNMENT,
      header: nil,
      width: nil,
      sort_by: nil,
      row_header: false,
      min_width: nil,
      max_width: nil
    )
      @id = id
      @field = field

      @align = align
      @header = header
      @width = fetch_or_fallback(COLUMN_WIDTH_OPTIONS, width) if width.present?
      @sort_by = sort_by
      @row_header = row_header
      @max_width = max_width
      @min_width = min_width
    end

    def header
      @header || super
    end

    def header?
      @header.present? || super
    end

    def call
      content
    end

    def render_cell(row)
      return @cell_block.call(row) if @cell_block
      return unless field

      row.public_send(field)
    end
  end
end
