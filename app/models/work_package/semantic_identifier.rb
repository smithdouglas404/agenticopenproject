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

  # Matches either a numeric ID ("12345") or a semantic identifier ("PROJ-42").
  # Used in Rails route constraints so both forms are accepted in URLs.
  # The frontend equivalent lives in WP_ID_URL_PATTERN (work-package-id-pattern.ts).
  ID_ROUTE_CONSTRAINT = /\d+|[A-Za-z][A-Za-z0-9_]*-\d+/

  # Finder methods that work on both the WorkPackage class and ActiveRecord::Relation scopes:
  #   semantic_id?("PROJ-42") → true
  #   semantic_id?(" 456 ")   → false  (stripped, then numeric)
  #   semantic_id?("123")     → false
  #   semantic_id?(123)       → false
  module FinderMethods
    def find(*args)
      return find_by_id_or_identifier!(args.first.strip) if args.length == 1 && semantic_id?(args.first)

      super
    end

    # Override find_by to transparently resolve semantic identifiers when called
    # with `id:` as the sole keyword (e.g. `find_by(id: "PROJ-42")`).
    # All other find_by calls pass through to ActiveRecord unchanged.
    #
    # AR's find_by signature is find_by(arg, *args) — it doesn't use keyword splat,
    # so hash kwargs arrive as the positional `arg`. We match on that.
    def find_by(*args)
      if args.length == 1 && args.first.is_a?(Hash) && args.first.keys == [:id] && semantic_id?(args.first[:id])
        find_by_id_or_identifier(args.first[:id])
      else
        super
      end
    end

    # Mirror of find_by — Rails implements find_by! independently (not via find_by),
    # so we must override both to keep the pair consistent.
    def find_by!(*args)
      if args.length == 1 && args.first.is_a?(Hash) && args.first.keys == [:id] && semantic_id?(args.first[:id])
        find_by_id_or_identifier!(args.first[:id])
      else
        super
      end
    end

    def exists?(conditions = :none)
      return super unless semantic_id?(conditions)

      exists_by_semantic_identifier?(conditions)
    end

    private

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
      find_by_id_or_identifier(identifier) ||
        raise(ActiveRecord::RecordNotFound.new(
                "Couldn't find WorkPackage with identifier=#{identifier}", "WorkPackage", "identifier", identifier
              ))
    end

    # Returns true when value looks like a semantic work package identifier (e.g. "PROJ-42").
    # Non-string values (Integer, Hash, nil, Array) and numeric strings ("123", " 456 ")
    # return false — these fall through to standard ActiveRecord lookup.
    def semantic_id?(value)
      return false unless value.is_a?(String)

      stripped = value.strip
      stripped.to_i.to_s != stripped
    end

    # Looks up by current identifier column first, then falls back to
    # the alias table for historical identifiers. Two-step because AR's
    # .or() requires structurally compatible relations (joins breaks it).
    def find_by_semantic_identifier(identifier)
      find_by(identifier:) ||
        by_semantic_alias(identifier).first
    end

    def exists_by_semantic_identifier?(identifier)
      where(identifier:).exists? ||
        by_semantic_alias(identifier).exists?
    end

    def by_semantic_alias(identifier)
      joins(:semantic_aliases).where(work_package_semantic_aliases: { identifier: })
    end
  end

  included do
    has_many :semantic_aliases,
             class_name: "WorkPackageSemanticAlias",
             foreign_key: :work_package_id,
             inverse_of: :work_package,
             dependent: :delete_all

    after_create :allocate_and_register_semantic_id, if: -> { Setting::WorkPackageIdentifier.semantic? }
  end

  class_methods do
    include FinderMethods

    # Extend every relation built from this model with semantic finder methods,
    # so that WorkPackage.visible(user).find("PROJ-42") works transparently.
    def relation
      super.extending(FinderMethods)
    end
  end

  # Returns the user-facing identifier for this work package.
  # In semantic mode: the project-based identifier (e.g. "PROJ-42")
  # In classic mode: the numeric database ID
  def display_id
    Setting::WorkPackageIdentifier.semantic_mode_active? ? identifier : id
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
