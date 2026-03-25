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

module OpenProject::Backlogs::List
  extend ActiveSupport::Concern

  included do
    # Once the scrum_projects_active feature flag is removed,
    # add
    #   scope [:project_id, :sprint_id]
    acts_as_list touch_on_update: false

    # acts as list adds a before destroy hook which messes
    # with the parent_id_was value
    skip_callback(:destroy, :before, :reload)

    # Reorder list, if work_package is removed from sprint
    # To be removed once the scrum_projects_active feature flag is removed
    before_update :fix_other_work_package_positions
    # To be removed once the scrum_projects_active feature flag is removed
    before_update :fix_own_work_package_position

    private

    # Used by acts_list to limit the list to a certain subset within
    # the table.
    #
    # Also sanitize_sql seems to be unavailable in a sensible way. Therefore
    # we're using send to circumvent visibility work_packages.
    def scope_condition
      if OpenProject::FeatureDecisions.scrum_projects_active?
        { project_id:, sprint_id: }
      else
        self.class.send(:sanitize_sql, ["project_id = ? AND version_id = ? AND type_id IN (?)",
                                        project_id, version_id, types])
      end
    end

    # rubocop:disable Style/ArrayIntersect
    # rubocop:disable Performance/InefficientHashSearch
    # Copied from acts_as_list.
    # To be removed once the scrum_projects_active feature flag is removed
    def scope_changed?
      return false unless OpenProject::FeatureDecisions.scrum_projects_active?

      (scope_condition.keys & changed.map(&:to_sym)).any?
    end

    # Copied from acts_as_list
    # To be removed once the scrum_projects_active feature flag is removed
    def destroyed_via_scope?
      return false unless OpenProject::FeatureDecisions.scrum_projects_active?
      return false unless destroyed_by_association

      foreign_key = destroyed_by_association.foreign_key
      if foreign_key.is_a?(Array)
        # Composite foreign key - check if any keys overlap with scope
        (scope_condition.keys & foreign_key.map(&:to_sym)).any?
      else
        # Single foreign key
        scope_condition.keys.include?(foreign_key.to_sym)
      end
    end
    # rubocop:enable Style/ArrayIntersect
    # rubocop:enable Performance/InefficientHashSearch

    include InstanceMethods
  end

  module InstanceMethods
    def move_after(position: nil, prev_id: nil)
      if acts_as_list_list.all?(position: nil)
        # If no items have a position, create an order on position
        # silently. This can happen when sorting inside a version for the first
        # time after backlogs was activated and there have already been items
        # inside the version at the time of backlogs activation
        set_default_prev_positions_silently(acts_as_list_list.last)
      end

      # Remove so the potential 'prev' has a correct position
      remove_from_list
      reload
      id_or_position = position ? { position: position - 1 } : { id: prev_id }

      prev = acts_as_list_list.find_by(**id_or_position)

      if prev.blank?
        # If it should be the first story, move it to the 1st position
        insert_at
        move_to_top
      else
        # There's a valid predecessor
        insert_at(prev.position + 1)
      end
    end

    protected

    # Override acts_as_list implementation to avoid it calling save.
    # Calling save would remove the changes/saved_changes information.
    def set_list_position(new_position, _raise_exception_if_save_fails = false) # rubocop:disable Style/OptionalBooleanParameter
      update_columns(position: new_position)
    end

    def fix_other_work_package_positions # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
      return if OpenProject::FeatureDecisions.scrum_projects_active?

      if changes.slice("project_id", "type_id", "version_id").present?
        if changes.slice("project_id", "version_id").blank? and
           Story.types.include?(type_id.to_i) and
           Story.types.include?(type_id_was.to_i)
          return
        end

        if version_id_changed?
          restore_version_id = true
          new_version_id = version_id
          self.version_id = version_id_was
        end

        if type_id_changed?
          restore_type_id = true
          new_type_id = type_id
          self.type_id = type_id_was
        end

        if project_id_changed?
          restore_project_id = true
          # I've got no idea, why there's a difference between setting the
          # project via project= or via project_id=, but there is.
          new_project = project
          self.project = Project.find(project_id_was)
        end

        remove_from_list if is_story?

        if restore_project_id
          self.project = new_project
        end

        if restore_type_id
          self.type_id = new_type_id
        end

        if restore_version_id
          self.version_id = new_version_id
        end
      end
    end

    def fix_own_work_package_position # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
      return if OpenProject::FeatureDecisions.scrum_projects_active?

      if changes.slice("project_id", "type_id", "version_id").present?
        if changes.slice("project_id", "version_id").blank? and
           Story.types.include?(type_id.to_i) and
           Story.types.include?(type_id_was.to_i)
          return
        end

        if is_story? and version.present?
          assume_bottom_position
        else
          remove_from_list
        end
      end
    end

    def set_default_prev_positions_silently(prev)
      return if prev.nil?

      if prev.is_task?
        prev.version.rebuild_task_positions(prev)
      else
        prev.version.rebuild_story_positions(prev.project)
      end

      prev.reload.position
    end
  end
end
