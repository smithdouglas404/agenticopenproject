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
  class TableComponent::HeaderComponent < Primer::Component
    DEFAULT_SCOPE = :col
    SCOPE_OPTIONS = [DEFAULT_SCOPE, :row].freeze

    def initialize(scope: DEFAULT_SCOPE, align: TableComponent::CellComponent::DEFAULT_ALIGNMENT, **system_arguments) # rubocop:disable Lint/MissingSuper
      resolved_scope = fetch_or_fallback(SCOPE_OPTIONS, scope, DEFAULT_SCOPE)
      resolved_align = fetch_or_fallback(
        TableComponent::CellComponent::ALIGNMENT_OPTIONS,
        align,
        TableComponent::CellComponent::DEFAULT_ALIGNMENT
      )

      @system_arguments = deny_tag_argument(**system_arguments)
      @system_arguments[:tag] = :th
      @system_arguments[:scope] = resolved_scope
      @system_arguments[:role] = resolved_scope == :row ? :rowheader : :columnheader
      @system_arguments[:data] = merge_data(
        @system_arguments, data: { cell_align: resolved_align }
      )
    end

    def call
      render(Primer::BaseComponent.new(**@system_arguments)) { content }
    end
  end
end
