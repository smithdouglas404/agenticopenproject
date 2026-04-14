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

module ProjectIdentifiers
  # Reverts a single project back to classic identifier mode:
  #
  # 1. Clears WP sequence_number and identifier (undoes backfill).
  # 2. Deletes WorkPackageSemanticAlias rows for WPs in this project.
  # 3. Restores the project identifier to its most-recent classic-format slug
  #    from FriendlyId history (undoes fix_identifier_if_needed).
  #    Projects that always had a valid semantic identifier have no classic slug
  #    and are left alone.
  # 4. Resets wp_sequence_counter to 0.
  class RevertProjectToClassicService
    def initialize(project)
      @project = project
    end

    def call
      ApplicationRecord.transaction do
        clear_wp_semantic_data
        clear_alias_rows
        restore_classic_identifier
        reset_sequence_counter
      end
    end

    private

    attr_reader :project

    def clear_wp_semantic_data
      WorkPackage.where(project:).update_all(sequence_number: nil, identifier: nil)
    end

    def clear_alias_rows
      WorkPackageSemanticAlias
        .where(work_package_id: WorkPackage.where(project:).select(:id))
        .delete_all
    end

    def restore_classic_identifier
      classic = previous_classic_identifier
      return unless classic

      project.update_columns(identifier: classic)
    end

    def reset_sequence_counter
      project.update_columns(wp_sequence_counter: 0)
    end

    # Returns the most-recent FriendlyId slug for this project that is in classic
    # (non-semantic) format, or nil if no such slug exists.
    def previous_classic_identifier
      detector = WorkPackages::IdentifierAutofix::ProblematicIdentifiers.new
      project.slugs
             .order(created_at: :desc)
             .pluck(:slug)
             .find { |slug| detector.format_error_reason(slug) }
    end
  end
end
