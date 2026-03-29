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

module WorkPackage::SemanticIdentifier
  extend ActiveSupport::Concern

  SEMANTIC_PATTERN = /\A([A-Za-z][A-Za-z0-9_]*)-(\d+)\z/
  # Matches both numeric IDs ("12345") and semantic identifiers ("PROJ-42").
  ID_ROUTE_CONSTRAINT = /(?:\d+|[A-Z][A-Z0-9_]*-\d+)/

  included do
    has_many :semantic_aliases,
             class_name: "WorkPackageSemanticAlias",
             foreign_key: :work_package_id,
             inverse_of: :work_package,
             dependent: :destroy

    after_create :register_semantic_id, if: -> { Setting::WorkPackageIdentifier.alphanumeric? }
  end

  class_methods do
    # Resolves any identifier form to a WorkPackage, applying visibility when user is given.
    #   - Numeric string ("12345")    → find by primary key
    #   - Semantic string ("PROJ-42") → registry lookup, then computed fallback
    #
    # Returns nil on miss.
    def find_by_identifier(identifier)
      identifier = identifier.to_s.strip
      return find_by(id: identifier) if identifier.match?(/\A\d+\z/)

      find_by_semantic_identifier(identifier)
    end

    # Same as find_by_identifier but raises ActiveRecord::RecordNotFound on miss.
    def find_by_identifier!(identifier)
      find_by_identifier(identifier) || raise(ActiveRecord::RecordNotFound, "WorkPackage not found: #{identifier}")
    end

    # Called after a WP moves to a different project. Retires the current identifier
    # as a historical alias, allocates a new identifier in the target project, and
    # updates sequence_number and semantic_id on the work package.
    def handle_wp_move(work_package)
      WorkPackageSemanticAlias.transaction do
        old_sid = work_package.semantic_id
        seq, sid = work_package.project.allocate_wp_semantic_identifier!
        work_package.update_columns(sequence_number: seq, semantic_id: sid)
        WorkPackageSemanticAlias.create!(identifier: old_sid, work_package_id: work_package.id) if old_sid
      end
    end

    # Called after a project identifier rename.
    #
    # Three things happen atomically:
    #
    # 1. New-prefix aliases are appended for WPs that previously moved out of this project,
    #    so both the old and the new prefix resolve.
    #
    # 2. The current semantic_id of every resident WP is inserted as a historical alias,
    #    retiring it before the rename takes effect.
    #
    # 3. semantic_id on resident WPs is updated to carry the new prefix.
    def handle_project_rename(project, old_identifier)
      like_pattern = "#{sanitize_sql_like(old_identifier)}-%"
      prefix = "#{old_identifier}-"
      new_prefix = "#{project.identifier}-"

      WorkPackageSemanticAlias.transaction do
        resident_wp_ids = where("semantic_id LIKE ?", like_pattern).pluck(:id)
        insert_moved_out_aliases(like_pattern, prefix, new_prefix, resident_wp_ids)
        insert_resident_rename_aliases(resident_wp_ids)
        update_resident_semantic_ids(resident_wp_ids, prefix, new_prefix)
      end
    end

    private

    # Append new-prefix aliases for WPs that previously moved out of this project
    def insert_moved_out_aliases(like_pattern, prefix, new_prefix, resident_wp_ids)
      rows = WorkPackageSemanticAlias
        .where("identifier LIKE ?", like_pattern)
        .where.not(work_package_id: resident_wp_ids)
        .pluck(:work_package_id, :identifier)
        .map { |wp_id, id| { identifier: new_prefix + id.delete_prefix(prefix), work_package_id: wp_id } }
      WorkPackageSemanticAlias.insert_all(rows, unique_by: :identifier) if rows.any?
    end

    # Insert pre-rename identifiers as historical aliases for resident WPs
    def insert_resident_rename_aliases(resident_wp_ids)
      rows = where(id: resident_wp_ids)
               .pluck(:id, :semantic_id)
               .map { |wp_id, sid| { identifier: sid, work_package_id: wp_id } }
      WorkPackageSemanticAlias.insert_all(rows, unique_by: :identifier) if rows.any?
    end

    # Update semantic_id on resident WPs to the new prefix
    def update_resident_semantic_ids(resident_wp_ids, prefix, new_prefix)
      where(id: resident_wp_ids).find_each do |wp|
        wp.update_columns(semantic_id: new_prefix + wp.semantic_id.delete_prefix(prefix))
      end
    end

    def find_by_semantic_identifier(identifier)
      # 1. Direct lookup — O(1) via work_packages.semantic_id index.
      #    Hits the common case (current identifier) without touching the alias table.
      wp = find_by(semantic_id: identifier)
      return wp if wp

      # 2. Alias registry lookup — O(1) via the unique index on identifier.
      #    Covers historic identifiers that are no longer the WP's semantic_id:
      #      - Historic identifiers retired on WP move ("PROJ-5" still resolves
      #        after the WP moved to OTHER, where it became "OTHER-42").
      #      - Historic identifiers retired on project rename ("PROJ-5" resolves
      #        after PROJ → PROJ_NEW; "PROJ_NEW-5" written at rename time).
      #      - Chained rename + move: "PROJ-5" moved to OTHER, then PROJ → PROJ_NEW
      #        → "PROJ_NEW-5" written at rename time via the old PROJ-5 registry row.
      #      - Multiple moves: WP moved PROJ → A → B — all three identifiers resolve.
      wp_id = WorkPackageSemanticAlias.find_by(identifier:)&.work_package_id
      return find_by(id: wp_id) if wp_id

      # 3+4. Computed fallback via project prefix + sequence_number, including ghost
      #      identifiers from rename+move chains.
      find_by_computed_fallback(identifier)
    end

    # Resolves identifiers that were never explicitly written to the alias table.
    # Covers "ghost" identifiers arising from project renames and move chains:
    #   - "PROJ-2" after PROJ → PROJ_NEW (new WP got PROJ_NEW-2, no PROJ-2 row).
    #   - "PROJ-5" after PROJ → PROJ_NEW then WP moved to OTHER ("PROJ_NEW-5" alias
    #     exists; reconstruct from current project name and look up in alias table).
    def find_by_computed_fallback(identifier)
      prefix, seq = parse_semantic_identifier(identifier)
      return nil unless prefix && seq

      project = resolve_project_by_prefix(prefix)
      return nil unless project

      find_by(project:, sequence_number: seq) || find_by_ghost_alias(project, seq)
    end

    # Handles the rename+move ghost case: the WP held sequence_number in this project
    # but has since moved away. Reconstruct its identifier under the current project
    # name and resolve via the alias table.
    def find_by_ghost_alias(project, seq)
      refreshed = "#{project.identifier}-#{seq}"
      wp_id = WorkPackageSemanticAlias.find_by(identifier: refreshed)&.work_package_id
      find_by(id: wp_id)
    end

    def parse_semantic_identifier(identifier)
      m = identifier.match(SEMANTIC_PATTERN)
      m ? [m[1], m[2].to_i] : nil
    end

    def resolve_project_by_prefix(prefix)
      Project.find_by(identifier: prefix) || Project.friendly.find(prefix)
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  private

  def register_semantic_id
    seq, sid = project.allocate_wp_semantic_identifier!
    update_columns(sequence_number: seq, semantic_id: sid)
    # No alias row on creation — the initial identifier is current, not historical.
    # It enters the alias table when the WP moves or the project is renamed.
  end
end
