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
    # Resolves any identifier form to a WorkPackage.
    #   - Numeric string ("12345")    → find by primary key
    #   - Semantic string ("PROJ-42") → alias table lookup
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

    private

    def find_by_semantic_identifier(identifier)
      # Fast path: Try direct lookup via the current semantic_id column first.
      # This uses the unique index on work_packages.semantic_id and resolves
      # the common case (current identifiers) in a single query.
      if (wp = find_by(semantic_id: identifier))
        return wp
      end

      # Fallback: Single alias table lookup — O(1) via the unique index on identifier.
      # The table holds every identifier a WP has ever been known by:
      #   - Written on creation for the initial identifier and all historical project prefixes.
      #   - Appended on project rename (new-prefix row for every affected WP).
      #   - Appended on WP move (old identifier row for the moved WP).
      wp_id = WorkPackageSemanticAlias.find_by(identifier: identifier)&.work_package_id
      find_by(id: wp_id)
    end
  end

  # Called after a WP moves to a different project. Allocates a new identifier in
  # the target project and updates sequence_number and semantic_id on the work package.
  #
  # Two alias writes happen atomically:
  # 1. The old semantic_id is retired (already present from creation/last move;
  #    unique_by silently skips the duplicate).
  # 2. The new identifier and every historical prefix of the destination project
  #    are written, so the WP is immediately findable under all of them.
  def handle_wp_move
    WorkPackageSemanticAlias.transaction do
      retire_row = semantic_id ? [{ identifier: semantic_id, work_package_id: id }] : []

      seq, sid = project.allocate_wp_semantic_identifier!
      update_columns(sequence_number: seq, semantic_id: sid)

      WorkPackageSemanticAlias.insert_all(retire_row + alias_rows_for(seq), unique_by: :identifier)
    end
  end

  private

  def register_semantic_id
    seq, sid = project.allocate_wp_semantic_identifier!
    update_columns(sequence_number: seq, semantic_id: sid)
    WorkPackageSemanticAlias.insert_all(alias_rows_for(seq), unique_by: :identifier)
  end

  # Builds alias rows for every identifier this project has ever used at the given sequence.
  def alias_rows_for(seq)
    project.semantic_identifier_aliases.map { |prefix| { identifier: "#{prefix}-#{seq}", work_package_id: id } }
  end
end
