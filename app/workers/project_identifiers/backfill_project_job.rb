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

class ProjectIdentifiers::BackfillProjectJob < ApplicationJob
  def perform(project_id)
    project = Project.find(project_id)
    fix_identifier_if_needed(project)
    backfill_work_packages(project)
  end

  private

  def fix_identifier_if_needed(project)
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
    project.save!(validate: false)
  end

  def backfill_work_packages(project)
    # Ensure the counter is at least as high as the highest existing sequence_number.
    # A WP moved in from another project may carry a sequence_number higher than the
    # local counter; without this sync, the nil loop would eventually collide with it.
    sync_sequence_counter(project)

    # Fix WPs that already have a sequence_number but an identifier that doesn't match
    # the current project prefix (caused by renames or cross-project moves in classic mode).
    fix_stale_identifiers(project)

    assign_missing_sequence_numbers(project)
    seed_alias_table(project)
  end

  def assign_missing_sequence_numbers(project)
    WorkPackage.where(project:, sequence_number: nil).order(:id).find_each do |wp|
      seq, identifier = project.allocate_wp_semantic_identifier!
      wp.update_columns(sequence_number: seq, identifier:)
    end
  end

  def sync_sequence_counter(project)
    max_seq = WorkPackage.where(project:).maximum(:sequence_number) || 0
    project.update_columns(wp_sequence_counter: max_seq) if max_seq > project.wp_sequence_counter
  end

  def fix_stale_identifiers(project)
    WorkPackage
      .where(project:)
      .where.not(sequence_number: nil)
      .where("identifier IS DISTINCT FROM ? || '-' || sequence_number::text", project.identifier)
      .find_each do |wp|
        wp.update_columns(identifier: "#{project.identifier}-#{wp.sequence_number}")
      end
  end

  def seed_alias_table(project)
    slug_prefixes = project.slugs.pluck(:slug)
    return if slug_prefixes.empty?

    alias_rows = WorkPackage.where(project:).pluck(:id, :sequence_number)
                            .product(slug_prefixes)
                            .map { |(wp_id, seq), prefix| { identifier: "#{prefix}-#{seq}", work_package_id: wp_id } }
    WorkPackageSemanticAlias.upsert_rows(alias_rows)
  end
end
