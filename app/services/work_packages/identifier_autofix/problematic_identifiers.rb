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

module WorkPackages
  module IdentifierAutofix
    # Identifies projects whose identifiers violate the semantic identifier format
    # and provides classification and exclusion sets for suggestion generation.
    #
    # For main use by admin UI preview and batch migration job.
    class ProblematicIdentifiers
      # Priority-ordered format rules for identifier classification.
      FORMAT_RULES = [
        [:too_long, ->(id, max) { id.length > max }],
        [:numerical, ->(id, _) { id.match?(/\A\d+\z/) }],
        [:starts_with_number, ->(id, _) { id.match?(/\A\d/) }],
        [:special_characters, ->(id, _) { id.match?(/[^a-zA-Z0-9]/) }],
        [:not_fully_uppercased, ->(id, _) { id != id.upcase }]
      ].freeze

      def scope
        @scope ||= exceeds_max_length
                      .or(contains_non_alphanumeric)
                      .or(starts_with_digit)
                      .or(not_fully_uppercased)
      end

      delegate :count, to: :scope

      # Returns a symbol classifying why the identifier is problematic.
      # Must handle all identifiers matched by #scope.
      def error_reason(identifier)
        format_error_reason(identifier) || collision_error_reason(identifier) || :unknown
      end

      # Returns a Set-like object for excluding already-taken identifiers
      # during suggestion generation.
      #
      # By default returns a DB-backed ExclusionSet that avoids loading all
      # identifiers into memory (suitable for preview with few projects).
      #
      # Pass +preload: true+ to eagerly load all identifiers into a plain Set
      # (suitable for batch jobs processing many projects).
      def exclusion_set(preload: false)
        if preload
          reserved_identifiers | in_use_identifiers_set
        else
          ExclusionSet.new(non_problematic_scope, local: reserved_identifiers)
        end
      end

      private

      def exceeds_max_length        = Project.where("length(identifier) > ?", max_identifier_length)
      def contains_non_alphanumeric = Project.where("identifier ~ ?", "[^a-zA-Z0-9]")
      def starts_with_digit         = Project.where("identifier ~ ?", "^[0-9]")
      def not_fully_uppercased      = Project.where("identifier != UPPER(identifier)")

      def max_identifier_length = ProjectIdentifierSuggestionGenerator::IDENTIFIER_LENGTH[:max]

      def format_error_reason(identifier)
        FORMAT_RULES.each do |reason, check|
          return reason if check.call(identifier, max_identifier_length)
        end
        nil
      end

      def collision_error_reason(identifier)
        # rubocop:disable Rails/WhereEquals, Rails/WhereExists -- raw SQL bypasses Rails normalizes on :identifier
        if non_problematic_scope.where("identifier = ?", identifier).exists?
          # rubocop:enable Rails/WhereEquals, Rails/WhereExists
          :in_use
        elsif reserved_identifiers.include?(identifier)
          :reserved
        end
      end

      def non_problematic_scope
        @non_problematic_scope ||= Project.where.not(id: scope.select(:id))
      end

      def in_use_identifiers_set
        @in_use_identifiers_set ||= non_problematic_scope.pluck(:identifier).to_set
      end

      def reserved_identifiers
        @reserved_identifiers ||= FriendlyId::Slug
                                    .where(sluggable_type: Project.name)
                                    .where.not(slug: Project.select(:identifier))
                                    .pluck(:slug)
                                    .to_set
      end

      # A Set-like object backed by an ActiveRecord scope that avoids
      # loading all identifiers into memory. Supports the interface
      # required by ProjectIdentifierSuggestionGenerator: include?, <<, dup.
      class ExclusionSet
        def initialize(scope, local: Set.new)
          @scope = scope
          @local = local
        end

        def include?(identifier)
          # Use raw SQL to bypass Rails normalizes on :identifier.
          @local.include?(identifier) || @scope.exists?(["identifier = ?", identifier])
        end

        def <<(identifier)
          @local << identifier
          self
        end

        def dup
          self.class.new(@scope, local: @local.dup)
        end

        def |(other)
          self.class.new(@scope, local: @local | other)
        end
      end
    end
  end
end
