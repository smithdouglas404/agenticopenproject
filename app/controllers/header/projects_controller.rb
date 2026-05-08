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

class Header::ProjectsController < ApplicationController
  no_authorization_required! :index

  MAX_NUMBER_OF_PROJECTS = 300

  def index
    @current_project_id = params[:current_project_id]&.to_i
    @jump               = params[:jump].presence
    @projects           = load_projects
    @favorited_ids      = load_favorited_ids
    @tree               = build_tree(@projects)

    render layout: false
  end

  private

  def query
    params[:query].to_s.strip
  end

  def filter_mode
    params[:filter_mode].to_s
  end

  def load_projects
    scope = Project.visible.active.order(:lft).limit(MAX_NUMBER_OF_PROJECTS)

    scope = scope.where("LOWER(name) LIKE LOWER(?)", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%") if query.present?

    if filter_mode == "favorited" && User.current.logged?
      favorite_ids = Favorite.where(favorited_type: "Project", user_id: User.current.id).select(:favorited_id)
      scope = scope.where(id: favorite_ids)
    end

    projects = scope.to_a

    # When not searching, ensure the current project is always present in the result
    # even if it sits beyond the MAX_NUMBER_OF_PROJECTS limit (e.g. large instances).
    if query.blank? && @current_project_id.present? && projects.none? { |p| p.id == @current_project_id }
      current = Project.visible.active.find_by(id: @current_project_id)

      if current
        # Include its ancestors so the tree path is intact.
        extras = current.self_and_ancestors.active.to_a
        projects = (projects + extras).uniq(&:id).sort_by(&:lft)
      end
    end

    projects
  end

  def load_favorited_ids
    return Set.new unless User.current.logged?

    Favorite
      .where(favorited_type: "Project", user_id: User.current.id, favorited_id: @projects.map(&:id))
      .pluck(:favorited_id)
      .to_set
  end

  # Builds a nested structure from a flat, lft-ordered list of projects.
  # Projects whose parent is not in the result set appear as roots.
  def build_tree(projects)
    nodes = projects.index_by(&:id).transform_values { |p| { project: p, children: [] } }

    roots = []
    projects.each do |project|
      node   = nodes[project.id]
      parent = nodes[project.parent_id]

      if parent
        parent[:children] << node
      else
        roots << node
      end
    end

    roots
  end
end
