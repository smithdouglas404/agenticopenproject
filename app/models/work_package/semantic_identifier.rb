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
  # Used as a route constraint on work_packages#show.
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

    private

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

      find_by(project:, sequence_number: seq)
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
    WorkPackageSemanticAlias.transaction do
      seq, sid = project.allocate_wp_semantic_identifier!
      update_columns(sequence_number: seq, semantic_id: sid)
      WorkPackageSemanticAlias.create!(identifier: sid, work_package_id: id)
    end
  end
end
