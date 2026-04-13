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

  included do
    has_many :semantic_aliases,
             class_name: "WorkPackageSemanticAlias",
             foreign_key: :work_package_id,
             inverse_of: :work_package,
             dependent: :delete_all

    after_create :allocate_and_register_semantic_id, if: -> { Setting::WorkPackageIdentifier.semantic? }
  end

  class_methods do
    def semantic_id?(identifier)
      identifier.to_s.to_i.to_s != identifier.to_s
    end

    # Resolves any identifier form to a WorkPackage.
    #   - Numeric string ("12345")    → find by primary key
    #   - Semantic string ("PROJ-42") → lookup via work_packages table and alias table
    #
    # Returns nil on miss.
    def find_by_id_or_identifier(identifier)
      return find_by(id: identifier) unless semantic_id?(identifier)

      find_by_semantic_identifier(identifier)
    end

    # Same as find_by_id_or_identifier but raises ActiveRecord::RecordNotFound on miss.
    def find_by_id_or_identifier!(identifier)
      find_by_id_or_identifier(identifier) || raise(ActiveRecord::RecordNotFound, "WorkPackage not found: #{identifier}")
    end

    private

    def find_by_semantic_identifier(identifier)
      wp = find_by(identifier:)
      return wp if wp

      # Fallback: alias table lookup. The table holds every identifier a WP has ever been known by:
      # Done via a single join to:
      # * Respect any parent scoping (e.g. when called as WorkPackage.visible.find_by_semantic_identifier)
      # * Reduce lookup to a single DB round trip
      joins(:semantic_aliases).find_by(work_package_semantic_aliases: { identifier: })
    end
  end

  # Allocates the next semantic identifier in the current project and assigns it to the WP.
  # Also writes alias rows for every identifier the project has ever used (including "ghost" aliases).
  #
  # This should generally be run following project_id-mutating operations on WorkPackage records (like create or move).
  def allocate_and_register_semantic_id
    WorkPackageSemanticAlias.transaction do
      sequence_number, identifier = project.allocate_wp_semantic_identifier!
      # Re-map the semantic identifier to the new project
      update_columns(sequence_number:, identifier:)
      # Insert current, historical + ghost aliases for the new project
      # Note: In case of WP move, the previous mapping for the old project is assumed
      #   to be present in the alias table already, ever since its prior create/move operation.
      semantic_aliases.insert_all(alias_rows_for_sequence_number(sequence_number),
                                  unique_by: :identifier)
    end
  end

  private

  # Builds alias rows for every identifier this project has ever used at the given sequence (including the current one).
  # This also includes "ghost identifiers" -- i.e. those that weren't ever actually generated, but should work
  # as a historical alias (e.g. OLDPROJ-42 should work even if WP #42 was created after rename to NEWPROJ)
  def alias_rows_for_sequence_number(seq)
    project.slugs
           .pluck(:slug)
           .map { |prefix| { identifier: "#{prefix}-#{seq}", work_package_id: id } }
  end
end
