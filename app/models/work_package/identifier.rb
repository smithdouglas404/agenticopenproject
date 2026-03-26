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

module WorkPackage::Identifier
  extend ActiveSupport::Concern

  SEMANTIC_PATTERN = /\A([A-Za-z][A-Za-z0-9_]*)-(\d+)\z/

  included do
    has_many :semantic_ids,
             class_name: "WorkPackageSemanticId",
             foreign_key: :work_package_id,
             inverse_of: :work_package,
             dependent: :destroy

    # Scoped read-only view; destruction is handled by has_many :semantic_ids above.
    has_one :current_semantic_id, # rubocop:disable Rails/HasManyOrHasOneDependent
            -> { where(current: true) },
            class_name: "WorkPackageSemanticId",
            foreign_key: :work_package_id,
            inverse_of: :work_package

    after_create :register_semantic_id, if: -> { Setting::WorkPackageIdentifier.alphanumeric? }
  end

  class_methods do
    # Resolves any identifier form to a WorkPackage, applying visibility when user is given.
    #   - Numeric string ("12345")    → find by primary key
    #   - Semantic string ("PROJ-42") → registry lookup, then computed fallback
    #
    # Returns nil on miss.
    def find_by_identifier(identifier, user: nil)
      identifier = identifier.to_s.strip
      return identifier_scope(user).find_by(id: identifier) if identifier.match?(/\A\d+\z/)

      find_by_semantic_identifier(identifier, user:)
    end

    # Same as find_by_identifier but raises ActiveRecord::RecordNotFound on miss.
    def find_by_identifier!(identifier, user: nil)
      find_by_identifier(identifier, user:) ||
        raise(ActiveRecord::RecordNotFound, "WorkPackage not found: #{identifier}")
    end

    private

    def find_by_semantic_identifier(identifier, user:)
      # 1. Registry lookup — O(1) via the unique index on identifier.
      #    Covers all identifiers written by the registry write operations:
      #      - Current identifier ("PROJ-5", "OTHER-42 after a move").
      #      - Historic identifiers retired on WP move ("PROJ-5" still resolves
      #        after the WP moved to OTHER, where it became "OTHER-42").
      #      - Historic identifiers retired on project rename ("PROJ-5" resolves
      #        after PROJ → PROJ_NEW; "PROJ_NEW-5" written at rename time).
      #      - Chained rename + move: "PROJ-5" moved to OTHER, then PROJ → PROJ_NEW
      #        → "PROJ_NEW-5" written at rename time via the old PROJ-5 registry row.
      #      - Multiple moves: WP moved PROJ → A → B — all three identifiers resolve.
      wp_id = WorkPackageSemanticId.find_by(identifier:)&.work_package_id
      return identifier_scope(user).find_by(id: wp_id) if wp_id

      # 2. Computed fallback — derives the WP from project + sequence_number using
      #    FriendlyId slug history to resolve retired project identifiers.
      #    Covers cases where no registry row exists for the requested identifier:
      #      - WPs created before the backfill has run (no registry rows yet).
      #      - Old prefix after multiple renames (PROJ → A → B → C): a WP created
      #        after the first rename has no "PROJ-N" row, but slug history lets us
      #        resolve "PROJ" → the project (now C) → find by sequence_number.
      #      - Identifier formed from a slug that was current when a link was saved
      #        but whose registry row is missing for any reason.
      prefix, seq = parse_semantic_identifier(identifier)
      return nil unless prefix && seq

      project = resolve_project_by_prefix(prefix)
      return nil unless project

      identifier_scope(user).find_by(project:, sequence_number: seq)
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

    def identifier_scope(user)
      user ? visible(user) : all
    end
  end

  private

  def register_semantic_id
    seq = project.with_lock { project.increment!(:wp_sequence_counter).wp_sequence_counter }
    update_columns(sequence_number: seq)
    WorkPackageSemanticId.create!(identifier: "#{project.identifier}-#{seq}", work_package_id: id, current: true)
  end
end
