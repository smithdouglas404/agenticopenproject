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
    #
    # == Performance notes
    #
    # * +#exclusion_set+ loads all non-problematic identifiers and historical slugs
    #   into memory. Fine for a one-off admin migration; if this ever becomes a hot
    #   path, consider a DB-backed exclusion check instead.
    #
    # * The regex scope conditions (+identifier ~ ?+) and +UPPER(identifier)+ won't
    #   hit a regular index. If queries get slow on large tables, a functional index
    #   on +UPPER(identifier)+ or a +pg_trgm+ GIN index would help.
    #
    #
    class ProblematicIdentifiers
      # Returns all project identifiers (current and historical) tracked by
      # FriendlyId's slug history. Useful as an exclusion set when generating
      # new identifiers, since any slug that was ever in use must not be reused.
      def self.reserved_identifiers
        FriendlyId::Slug.where(sluggable_type: Project.name).pluck(:slug).to_set
      end

      # Priority-ordered format rules for identifier classification.
      FORMAT_RULES = [
        [:too_long, ->(id, max) { id.length > max }],
        [:numerical, ->(id, _) { id.match?(/\A\d+\z/) }],
        [:starts_with_number, ->(id, _) { id.match?(/\A\d/) }],
        [:special_characters, ->(id, _) { id.match?(/[^a-zA-Z0-9_]/) }],
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

      # Returns a Set of identifiers that must not be suggested for new assignments.
      # Combines currently active identifiers from non-problematic projects with
      # historically reserved identifiers from FriendlyId slug history.
      def exclusion_set
        historical_identifiers | in_use_identifiers
      end

      private

      def historical_identifiers
        @historical_identifiers ||= FriendlyId::Slug
                                    .where(sluggable_type: Project.name)
                                    .where("LOWER(slug) NOT IN (SELECT LOWER(identifier) FROM projects)")
                                    .pluck(:slug)
                                    .to_set
      end

      def exceeds_max_length        = Project.where("length(identifier) > ?", max_identifier_length)
      def contains_non_alphanumeric = Project.where("identifier ~ ?", "[^a-zA-Z0-9_]")
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
        if in_use_identifiers.include?(identifier)
          :in_use
        elsif historical_identifiers.include?(identifier)
          :reserved
        end
      end

      def in_use_identifiers
        @in_use_identifiers ||= Project.where.not(id: scope.select(:id)).pluck(:identifier).to_set
      end

    end
  end
end
