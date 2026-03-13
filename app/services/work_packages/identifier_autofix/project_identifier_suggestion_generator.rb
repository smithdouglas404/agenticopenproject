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
    # Generates a short uppercase acronym suggestion for each given project.
    #
    # The suggestion is derived from the project name: taking the first letter of
    # each word and uppercasing ("Flight Planning Algorithm" → "FPA"). When two
    # projects produce the same acronym, a numeric suffix resolves the collision
    # ("SC", "SC2", "SC3", …).
    #
    class ProjectIdentifierSuggestionGenerator
      MAX_IDENTIFIER_LENGTH = 10
      DEFAULT_IDENTIFIER_BASE_LENGTH = 5
      SINGLE_WORD_LENGTH = 3
      FALLBACK_IDENTIFIER = "PROJ"
      SUFFIX_LIMIT = 10_000

      def self.call(projects, reserved_identifiers: Set.new, in_use_identifiers: Set.new)
        new.call(projects, reserved_identifiers:, in_use_identifiers:)
      end

      # Returns a single suggested identifier string for the given project name.
      #
      def self.suggest_identifier(name, reserved_identifiers: Set.new, in_use_identifiers: Set.new)
        new.suggest_identifier(name, reserved_identifiers:, in_use_identifiers:)
      end

      def call(projects, reserved_identifiers:, in_use_identifiers:)
        generate_suggestions(projects, reserved_identifiers:, in_use_identifiers:)
      end

      def suggest_identifier(name, reserved_identifiers: Set.new, in_use_identifiers: Set.new)
        base = identifier_from_name(name)
        unique_identifier(base, combined_identifiers(reserved_identifiers, in_use_identifiers))
      end

      private

      def generate_suggestions(projects, reserved_identifiers:, in_use_identifiers:)
        used_identifiers = combined_identifiers(reserved_identifiers, in_use_identifiers)

        projects.map do |project|
          base       = identifier_from_name(project.name)
          identifier = unique_identifier(base, used_identifiers)
          used_identifiers << identifier

          {
            project:,
            current_identifier: project.identifier,
            suggested_identifier: identifier
          }
        end
      end

      def identifier_from_name(name)
        # Use POSIX [[:alpha:]] so accented letters (é, ñ, ü…) are kept inside
        # their word rather than treated as separators by the ASCII-only [a-zA-Z].
        words = name.to_s.scan(/[[:alpha:][:digit:]]+/)
        return FALLBACK_IDENTIFIER if words.empty?

        words.size == 1 ? identifier_from_single_word(words.first) : identifier_from_words(words)
      end

      def identifier_from_single_word(word)
        # e.g. "Banana" → "BAN", "Kiwi" → "KIW", "日本語" → FALLBACK_IDENTIFIER
        t = I18n.with_locale(:en) { I18n.transliterate(word) }
        chars = t.scan(/[A-Za-z0-9]/).first(SINGLE_WORD_LENGTH).map(&:upcase).join
        chars.empty? ? FALLBACK_IDENTIFIER : chars
      end

      def identifier_from_words(words)
        # Multi-word names: take initials (first letter of each word), truncated.
        acronym = words.filter_map do |word|
          ch = I18n.with_locale(:en) { I18n.transliterate(word[0]) }.upcase[0]
          ch if ch&.match?(/\A[A-Z0-9]\z/)
        end.join
        return FALLBACK_IDENTIFIER if acronym.empty?

        acronym.slice(0, DEFAULT_IDENTIFIER_BASE_LENGTH)
      end

      def unique_identifier(base, used_identifiers)
        return base unless used_identifiers.include?(base)

        counter = 2
        loop do
          raise "Could not find a unique identifier for base '#{base}' within #{SUFFIX_LIMIT} attempts" \
            if counter > SUFFIX_LIMIT

          suffix    = counter.to_s
          candidate = "#{base.slice(0, DEFAULT_IDENTIFIER_BASE_LENGTH - suffix.length)}#{suffix}"
          break candidate unless used_identifiers.include?(candidate)

          counter += 1
        end
      end

      def combined_identifiers(*sets)
        sets.reduce(Set.new, :merge)
      end
    end
  end
end
