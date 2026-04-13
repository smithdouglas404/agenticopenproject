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
  # Brings a single project fully up to date for semantic identifier mode:
  #
  # 1. Fixes the project identifier if it is not in valid semantic format.
  # 2. Syncs the sequence counter so it is >= any existing sequence_number
  #    (guards against counter underflow caused by cross-project WP moves).
  # 3. Rewrites stale WP identifiers whose prefix no longer matches the project.
  # 4. Assigns sequence numbers to WPs that have none yet.
  # 5. Seeds the alias table for all historical project identifier prefixes.
  class ConvertProjectToSemanticService
    def initialize(project)
      @project = project
    end

    def call
      ApplicationRecord.transaction do
        fix_identifier_if_needed
        reset_stale_identifiers
        backfill_missing_ids
        seed_alias_table
      end
    end

    private

    attr_reader :project

    def fix_identifier_if_needed
      detector  = WorkPackages::IdentifierAutofix::ProblematicIdentifiers.new
      generator = WorkPackages::IdentifierAutofix::ProjectIdentifierSuggestionGenerator
      # Pure format check — no DB queries. nil means the identifier is fine.
      return unless detector.format_error_reason(project.identifier)

      # Prefer restoring the project's last known semantic identifier (from FriendlyId history)
      # so that existing WP identifiers remain valid and aliases need no update.
      # Fall back to generating a fresh suggestion if no usable prior slug exists.
      # Two concurrent jobs may occasionally suggest the same identifier, but the
      # unique constraint on projects.identifier will reject the second writer, and
      # the job can be retried.
      new_identifier = project.previous_semantic_identifier ||
                       generator.suggest_identifier(project.name, exclude: detector.exclusion_set)

      project.identifier = new_identifier
      project.save!
    end

    def reset_stale_identifiers
      # Fix WPs that contain identifier that doesn't match the current project prefix
      #   (caused by renames or cross-project moves in classic mode)
      WorkPackage
        .where(project:)
        .where.not(sequence_number: nil)
        .where("identifier NOT LIKE ?", "#{project.identifier}-%")
        .update_all(identifier: nil, sequence_number: nil)
    end

    def backfill_missing_ids
      WorkPackage.where(project:, sequence_number: nil).order(:id).find_each do |wp|
        seq, identifier = project.allocate_wp_semantic_identifier!
        wp.update_columns(sequence_number: seq, identifier:)
      end
    end

    def seed_alias_table
      slug_prefixes = project.slugs.pluck(:slug)
      return if slug_prefixes.empty?

      WorkPackage.where(project:).where.not(sequence_number: nil).in_batches do |batch|
        alias_rows = batch.pluck(:id, :sequence_number)
                          .product(slug_prefixes)
                          .map { |(wp_id, seq), prefix| { identifier: "#{prefix}-#{seq}", work_package_id: wp_id } }
        WorkPackageSemanticAlias.upsert_rows(alias_rows)
      end
    end
  end
end
