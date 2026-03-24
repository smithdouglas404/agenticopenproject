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

      def call
        total   = problematic_scope.count
        preview = problematic_scope
                    .select(:id, :name, :identifier)
                    .limit(DISPLAY_COUNT)
                    .to_a

        suggestions = WorkPackages::IdentifierAutofix::ProjectIdentifierSuggestionGenerator.call(
          preview,
          exclude: reserved_identifiers | in_use_identifiers
        )

        projects_data = suggestions.map do |entry|
          entry.merge(error_reason: error_reason(entry[:current_identifier]))
        end

        Result.new(projects_data:, total_count: total)
      end

      private

      def problematic_scope
        @problematic_scope ||= Project.where(
          "length(identifier) > ? OR identifier ~ ?",
          ProjectIdentifierSuggestionGenerator::IDENTIFIER_LENGTH[:max],
          "[^a-zA-Z0-9_]"
        )
      end

      def error_reason(identifier)
        if identifier.length > ProjectIdentifierSuggestionGenerator::IDENTIFIER_LENGTH[:max]
          :too_long
        elsif identifier.match?(/[^a-zA-Z0-9_]/)
          :special_characters
        elsif in_use_identifiers.include?(identifier)
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
