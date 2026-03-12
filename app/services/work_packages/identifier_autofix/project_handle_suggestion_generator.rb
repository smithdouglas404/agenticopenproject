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
    # Each result entry includes an error_reason classifying why the project's
    # current identifier is problematic:
    #   - :too_long            — identifier length exceeds HANDLE_MAX_LENGTH
    #   - :special_characters  — identifier contains characters outside [a-zA-Z0-9]
    #   - :in_use              — identifier is another project's active handle
    #   - :reserved            — identifier appears in another project's handle history
    #
    class ProjectHandleSuggestionGenerator
      HANDLE_MAX_LENGTH = 5
      SINGLE_WORD_LENGTH = 3
      FALLBACK_HANDLE = "PROJ"
      SUFFIX_LIMIT = 10_000

      def self.call(projects, reserved_handles: Set.new, in_use_handles: Set.new)
        new.call(projects, reserved_handles:, in_use_handles:)
      end

      def self.suggest_for_name(name)
        new.suggest_for_name(name)
      end

      def suggest_for_name(name)
        handle_from_name(name)
      end

      def call(projects, reserved_handles:, in_use_handles:)
        generate_suggestions(projects, reserved_handles:, in_use_handles:)
      end

      private

      def generate_suggestions(projects, reserved_handles:, in_use_handles:)
        used_handles = Set.new
        used_handles.merge(in_use_handles)
        used_handles.merge(reserved_handles)

        projects.map do |project|
          base   = handle_from_name(project.name)
          handle = unique_handle(base, used_handles)
          used_handles << handle

          {
            project:,
            current_identifier: project.identifier,
            suggested_handle: handle,
            error_reason: error_reason(project.identifier, reserved_handles:, in_use_handles:)
          }
        end
      end

      def handle_from_name(name)
        # Use POSIX [[:alpha:]] so accented letters (é, ñ, ü…) are kept inside
        # their word rather than treated as separators by the ASCII-only [a-zA-Z].
        words = name.to_s.scan(/[[:alpha:][:digit:]]+/)
        return FALLBACK_HANDLE if words.empty?

        words.size == 1 ? handle_from_single_word(words.first) : handle_from_words(words)
      end

      def handle_from_single_word(word)
        # e.g. "Banana" → "BAN", "Kiwi" → "KIW", "日本語" → FALLBACK_HANDLE
        t = I18n.with_locale(:en) { I18n.transliterate(word) }
        chars = t.scan(/[A-Za-z0-9]/).first(SINGLE_WORD_LENGTH).map(&:upcase).join
        chars.empty? ? FALLBACK_HANDLE : chars
      end

      def handle_from_words(words)
        # Multi-word names: take initials (first letter of each word), truncated.
        acronym = words.filter_map do |word|
          ch = I18n.with_locale(:en) { I18n.transliterate(word[0]) }.upcase[0]
          ch if ch&.match?(/\A[A-Z0-9]\z/)
        end.join
        return FALLBACK_HANDLE if acronym.empty?

        acronym.slice(0, HANDLE_MAX_LENGTH)
      end

      def unique_handle(base, used_handles)
        return base unless used_handles.include?(base)

        counter = 2
        loop do
          raise "Could not find a unique handle for base '#{base}' within #{SUFFIX_LIMIT} attempts" \
            if counter > SUFFIX_LIMIT

          suffix    = counter.to_s
          candidate = "#{base.slice(0, HANDLE_MAX_LENGTH - suffix.length)}#{suffix}"
          break candidate unless used_handles.include?(candidate)

          counter += 1
        end
      end

      def error_reason(identifier, reserved_handles:, in_use_handles:)
        if identifier.length > HANDLE_MAX_LENGTH
          :too_long
        elsif identifier.match?(/[^a-zA-Z0-9]/)
          :special_characters
        elsif in_use_handles.include?(identifier)
          :in_use
        elsif reserved_handles.include?(identifier)
          :reserved
        end
      end
    end
  end
end
