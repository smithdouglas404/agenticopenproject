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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Projects::SprintSharing
  extend ActiveSupport::Concern

  NO_SHARING         = "no_sharing"
  SHARE_ALL_PROJECTS = "share_all_projects"
  SHARE_SUBPROJECTS  = "share_subprojects"
  RECEIVE_SHARED     = "receive_shared"

  SPRINT_SHARING_MODES = [NO_SHARING, SHARE_ALL_PROJECTS, SHARE_SUBPROJECTS, RECEIVE_SHARED].freeze

  included do
    store_attribute :settings, :sprint_sharing, :string

    scopes :share_sprints_with_all_projects,
           :share_sprints_with_subprojects,
           :receive_shared_sprints,
           :not_sharing_sprints
  end

  class_methods do
    def global_sprint_sharer
      global_sprint_sharer_relation.first
    end

    def global_sprint_sharer_relation
      share_sprints_with_all_projects.active.limit(1)
    end
  end

  # `default:` cannot be reliably used on the store_attribute declaration,
  # see config/initializers/store_attribute.rb for more details.
  def sprint_sharing
    super || NO_SHARING
  end

  def share_sprints_with_all_projects?
    sprint_sharing == SHARE_ALL_PROJECTS
  end

  def share_sprints_with_subprojects?
    sprint_sharing == SHARE_SUBPROJECTS
  end

  def receive_shared_sprints?
    sprint_sharing == RECEIVE_SHARED
  end

  def not_sharing_sprints?
    sprint_sharing == NO_SHARING
  end

  def not_sharing_sprints!
    return if not_sharing_sprints?

    update_column(:settings, settings.merge("sprint_sharing" => NO_SHARING))
  end

  def sprint_source
    # Senders and non-sharing projects only see their own sprints.
    # Receivers see external sprints from the closest ancestor sharing
    # subprojects, falling back to the global sharer.
    if receive_shared_sprints?
      closest_sharing_ancestor_or_global_sharer
    else
      self.class.where(id:)
    end
  end

  private

  def closest_sharing_ancestor_or_global_sharer
    closest_ancestor = ancestors.share_sprints_with_subprojects.reorder(lft: :desc).limit(1)

    self.class
      .where(id: closest_ancestor).limit(1) # Both sides of `or` must be structurally identical
      .or(self.class.global_sprint_sharer_relation.where.not(closest_ancestor.arel.exists))
  end
end
