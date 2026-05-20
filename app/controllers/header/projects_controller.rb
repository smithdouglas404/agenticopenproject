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
  VALID_FILTER_MODES = %w[all favorited].freeze

  def index
    @current_project_id = params[:current_project_id]&.to_i
    @jump = params[:jump].presence
    @projects = load_projects
    @favorited_ids = load_favorited_ids
    @tree = build_tree(@projects)

    render layout: false
  end

  private

  def query
    params[:query].to_s.strip
  end

  def filter_mode
    mode = params[:filter_mode].to_s
    VALID_FILTER_MODES.include?(mode) ? mode : "all"
  end

  def load_projects
    projects = base_scope.to_a
    projects = ensure_current_project_present(projects)

    if query.present? && projects.any?
      @matching_ids = projects.to_set(&:id)
      ancestors = ancestor_scope_for(projects).to_a
      projects = (projects + ancestors).uniq(&:id).sort_by(&:lft)
    end

    projects
  end

  def base_scope
    scope = Project.visible.active.order(:lft).limit(MAX_NUMBER_OF_PROJECTS)
    query.split.each do |term|
      scope = scope.where("LOWER(name) LIKE LOWER(?)", "%#{ActiveRecord::Base.sanitize_sql_like(term)}%")
    end
    if filter_mode == "favorited"
      scope = User.current.logged? ? scope.where(id: favorite_project_ids) : scope.none
    end
    scope
  end

  def ensure_current_project_present(projects)
    return projects if skip_current_project_inclusion?
    return projects if projects.any? { |p| p.id == @current_project_id }

    current = Project.visible.active.find_by(id: @current_project_id)
    return projects unless current

    merge_with_ancestors(projects, current)
  end

  def skip_current_project_inclusion?
    query.present? || filter_mode == "favorited" || @current_project_id.blank?
  end

  def merge_with_ancestors(projects, current)
    (projects + current.self_and_ancestors.active.to_a).uniq(&:id).sort_by(&:lft)
  end

  # Returns a scope for all visible, active ancestors of the given projects
  # that are not already in the given list.
  def ancestor_scope_for(projects)
    Project.visible.active
           .where(ancestor_condition(projects))
           .where.not(id: projects.map(&:id))
  end

  def ancestor_condition(projects)
    projects.map { |p| within_bounds(p.lft, p.rgt) }.reduce(:or)
  end

  def within_bounds(lft, rgt)
    Project.arel_table[:lft].lt(lft).and(Project.arel_table[:rgt].gt(rgt))
  end

  def favorite_project_ids
    user_project_favorites.select(:favorited_id)
  end

  def load_favorited_ids
    return Set.new unless User.current.logged?

    user_project_favorites
      .where(favorited_id: @projects.map(&:id))
      .pluck(:favorited_id)
      .to_set
  end

  def user_project_favorites
    @user_project_favorites ||= Favorite.where(favorited_type: "Project", user_id: User.current.id)
  end

  # Builds a nested structure from a flat, lft-ordered list of projects.
  # Each level is sorted alphabetically by project name.
  def build_tree(projects)
    nodes = projects.index_by(&:id).transform_values do |p|
      { project: p, children: [], matches_query: @matching_ids.nil? || @matching_ids.include?(p.id) }
    end

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

    sort_nodes(roots)
  end

  def sort_nodes(nodes)
    nodes.sort_by { |n| n[:project].name.downcase }.each do |node|
      node[:children] = sort_nodes(node[:children])
      node[:expanded] = node[:children].any? { |c| c[:project].id == @current_project_id || c[:expanded] }
    end
  end
end
