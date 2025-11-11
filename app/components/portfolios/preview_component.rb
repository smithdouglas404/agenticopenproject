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

module Portfolios
  class PreviewComponent < ApplicationComponent
    include ApplicationHelper
    include OpPrimer::ComponentHelpers
    include WorkspaceHelper

    attr_reader :current_user, :portfolio

    def initialize(portfolio:, current_user:)
      super
      @portfolio = portfolio
      @current_user = current_user
    end

    def currently_favorited?
      @currently_favorited ||= favorited_project_ids.include?(portfolio.id)
    end

    def all_subprograms
      all_descendants.filter { it.workspace_type == "program" }
    end

    def all_subprojects
      all_descendants.filter { it.workspace_type == "project" }
    end

    private

    def favorited_project_ids
      @favorited_project_ids ||= Favorite.where(user: current_user, favorited_type: "Project").pluck(:favorited_id)
    end

    def all_descendants(project = portfolio)
      return @descendants if defined?(@descendants)

      @descendants = Set.new
      stack = [project]

      until stack.empty?
        current = stack.pop
        current.descendants.each { stack.push(it) }

        @descendants.add(current) unless current == project
      end

      @descendants
    end
  end
end
