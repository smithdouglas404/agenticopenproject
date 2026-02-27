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

  SPRINT_SHARING_OPTIONS = [NO_SHARING, SHARE_ALL_PROJECTS, SHARE_SUBPROJECTS, RECEIVE_SHARED].freeze

  included do
    store_attribute :settings, :sprint_sharing, :string

    scope :sprint_sharing, ->(value) { where("settings->>'sprint_sharing' = ?", value) }
    scope :share_sprints_with_all_projects, -> { sprint_sharing(SHARE_ALL_PROJECTS) }
    scope :share_sprints_with_subprojects, -> { sprint_sharing(SHARE_SUBPROJECTS) }
    scope :receive_shared_sprints, -> { sprint_sharing(RECEIVE_SHARED) }
    scope :not_sharing_sprints, -> { sprint_sharing(NO_SHARING) }

    validate :validate_sprint_sharer_uniqueness

    # TODO: Change the store_attribute_unset_values_fallback_to_default to true in the
    # config/initializers/store_attribute.rb.
    # Otherwise defaults set on the setting declaration are not working correctly:
    # `store_attribute :settings, :sprint_sharing, :string, default: "no_sharing"`.
    # The method getter override below is required to provide the default value.

    def sprint_sharing
      super.presence || NO_SHARING
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

    def receive_sprints_from
      # If there are multiple projects from which a receiving project could take its sprints
      # the order of priority is as follows (lowest to highest priority):
      #   => All projects sharing
      #   => Subproject sharing higher up the ancestor chain
      case sprint_sharing
      when NO_SHARING, nil
        [self]
      when RECEIVE_SHARED, SHARE_SUBPROJECTS
        [self, ancestors.share_sprints_with_subprojects.last || self.class.sprint_sharer].compact
      when SHARE_ALL_PROJECTS
        [self, ancestors.share_sprints_with_subprojects.last].compact
      end
    end

    private

    def validate_sprint_sharer_uniqueness
      if sprint_sharing == SHARE_ALL_PROJECTS &&
         (sharer = self.class.sprint_sharer) &&
         sharer != self

        errors.add :sprint_sharing, :share_all_projects_already_taken, name: sharer.name
      end
    end
  end

  class_methods do
    def sprint_sharer
      share_sprints_with_all_projects.first
    end
  end
end
