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

class WorkPackages::ConvertInstanceToSemanticIds::BackfillProjectJob < ApplicationJob
  def perform(project_id)
    project = Project.find(project_id)
    fix_identifier_if_needed(project)
    backfill_work_packages(project)
  end

  private

  def fix_identifier_if_needed(project)
    detector = WorkPackages::IdentifierAutofix::ProblematicIdentifiers.new
    # Pure format check — no DB queries. nil means the identifier is fine.
    return unless detector.format_error_reason(project.identifier)

    # Build the exclusion set fresh from the DB at job-execution time.
    # Two concurrent jobs may occasionally suggest the same identifier, but the
    # unique constraint on projects.identifier will reject the second writer, and
    # the job can be retried.
    new_identifier = WorkPackages::IdentifierAutofix::ProjectIdentifierSuggestionGenerator
                       .suggest_identifier(project.name, exclude: detector.exclusion_set)
    project.identifier = new_identifier
    project.save!(validate: false)
  end

  def backfill_work_packages(project)
    # Assign sequence numbers to any WPs that don't have one yet (oldest first).
    WorkPackage.where(project:, sequence_number: nil).order(:id).find_each do |wp|
      seq, identifier = project.allocate_wp_semantic_identifier!
      wp.update_columns(sequence_number: seq, identifier:)
    end

    seed_alias_table(project)
  end

  def seed_alias_table(project)
    # Bulk-insert alias rows for every historical project identifier prefix so that
    # old-style references (e.g. OLDPROJ-42) continue to resolve after a rename.
    alias_rows = WorkPackage.where(project:).flat_map do |wp|
      wp.alias_rows_for_sequence_number(wp.sequence_number)
    end
    WorkPackageSemanticAlias.upsert_rows(alias_rows)
  end
end
