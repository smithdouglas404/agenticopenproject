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
    class PreviewQuery
      Result = Data.define(:projects_data, :total_count)
      DISPLAY_COUNT = 5

      # Priority-ordered format rules for identifier classification.
      FORMAT_RULES = [
        [:too_long, ->(id, max) { id.length > max }],
        [:numerical, ->(id, _) { id.match?(/\A\d+\z/) }],
        [:starts_with_number, ->(id, _) { id.match?(/\A\d/) }],
        [:special_characters, ->(id, _) { id.match?(/[^a-zA-Z0-9]/) }],
        [:not_uppercase, ->(id, _) { id != id.upcase }]
      ].freeze

      def call
        Result.new(projects_data: build_projects_data, total_count: problematic_scope.count)
      end

      private

      def build_projects_data
        generate_suggestions.map do |entry|
          entry.merge(error_reason: error_reason(entry[:current_identifier]))
        end
      end

      def generate_suggestions
        ProjectIdentifierSuggestionGenerator.call(
          preview_projects,
          exclude: reserved_identifiers | in_use_identifiers
        )
      end

      def preview_projects
        problematic_scope
          .select(:id, :name, :identifier)
          .limit(DISPLAY_COUNT)
          .to_a
      end

      # Scope conditions must cover all identifiers classifiable by #error_reason.
      def problematic_scope
        @problematic_scope ||= exceeds_max_length
                                 .or(contains_non_alphanumeric)
                                 .or(starts_with_digit)
                                 .or(not_fully_uppercased)
      end

      def exceeds_max_length        = Project.where("length(identifier) > ?", max_identifier_length)
      def contains_non_alphanumeric = Project.where("identifier ~ ?", "[^a-zA-Z0-9]")
      def starts_with_digit         = Project.where("identifier ~ ?", "^[0-9]")
      def not_fully_uppercased      = Project.where("identifier != UPPER(identifier)")

      def max_identifier_length = ProjectIdentifierSuggestionGenerator::IDENTIFIER_LENGTH[:max]

      # Must handle all identifiers matched by #problematic_scope.
      def error_reason(identifier)
        format_error_reason(identifier) || collision_error_reason(identifier) || :unknown
      end

      def format_error_reason(identifier)
        FORMAT_RULES.each do |reason, check|
          return reason if check.call(identifier, max_identifier_length)
        end
        nil # no format rule matched
      end

      def collision_error_reason(identifier)
        if in_use_identifiers.include?(identifier)
          :in_use
        elsif reserved_identifiers.include?(identifier)
          :reserved
        end
      end

      def in_use_identifiers
        @in_use_identifiers ||= Project.where.not(id: problematic_scope.select(:id)).pluck(:identifier).to_set
      end

      def reserved_identifiers
        # TODO: OldProjectIdentifier.pluck(:identifier).to_set
        # once the OldProjectIdentifier model and migration are added.
        Set.new
      end
    end
  end
end
