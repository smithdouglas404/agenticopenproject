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
  # Scans projects for identifiers that do not meet alphanumeric handle
  # requirements and generates a short uppercase acronym suggestion for each one.
  #
  # A "problematic" identifier is one that (error_reason):
  #   - is longer than HANDLE_MAX_LENGTH (10) characters          → :too_long
  #   - contains any character outside [a-zA-Z0-9]                → :special_characters
  #   FIXME(project_handles): Two further cases once model exists:
  #   - the identifier string is already in project_handles for
  #     another project (current or historical)                   → :handle_reserved
  #   - the identifier is valid format but will be auto-adopted
  #     as another project's handle during migration              → :identifier_taken
  #
  # The suggestion is derived from the project name: taking the first letter of
  # each word and uppercasing ("Flight Planning Algorithm" → "FPA"). When two
  # projects produce the same acronym, a numeric suffix resolves the collision
  # ("SC", "SC2", "SC3", …).
  #
  # FIXME(project_handles): This class currently reads from the existing
  # Project#identifier column. Once the project_handles data model is available,
  # replace #call with a query that finds projects with no current handle row:
  #
  #   Project
  #     .select(:id, :name, :identifier)
  #     .where.not(id: ProjectHandle.where(current: true).select(:project_id))
  #     .to_a
  #     .then { |projects_without_handle| generate_suggestions(projects_without_handle) }
  #
  # project_handles stores only valid (alphanumeric, ≤ HANDLE_MAX_LENGTH) handles.
  # A project with no current handle is one whose Project#identifier has not yet been
  # migrated; generate_suggestions still uses Project#identifier as current_identifier
  # and error_reason still classifies why that identifier is problematic.
  # The :current boolean marks the live handle; superseded handles are retained so
  # that existing URLs continue to resolve via redirect.
  class ProjectHandleSuggestionGenerator
    HANDLE_MAX_LENGTH = 10
    FALLBACK_HANDLE = "PROJ"
    # Upper bound for suffix counter — prevents an infinite loop if used_handles
    # is somehow saturated. 10 000 projects sharing an acronym is unreachable in
    # practice; raising here indicates a serious bug in the caller's pre-seeding.
    SUFFIX_LIMIT = 10_000

    # @return [Array<Hash>] one entry per project with a problematic identifier:
    #   { project:, current_identifier:, suggested_handle:, error_reason: }
    #   error_reason is :too_long, :special_characters,
    #   :handle_reserved, or :identifier_taken (last two: FIXME project_handles)
    def self.call
      new.call
    end

    def call
      # FIXME(project_handles): Replace with projects lacking a current handle — see class doc above.
      # Note: the future query (Project.where.not(id: ProjectHandle.where(current:true)…))
      # also naturally surfaces :handle_reserved and :identifier_taken projects because
      # they too will have no valid current handle row. No extra WHERE filter is needed;
      # the key change is pre-seeding used_handles in generate_suggestions (see below).
      Project
        .select(:id, :name, :identifier)
        .where("length(identifier) > ? OR identifier ~ ?", HANDLE_MAX_LENGTH, "[^a-zA-Z0-9]")
        .to_a
        .then { generate_suggestions(it) }
    end

    private

    def error_reason(identifier)
      if identifier.length > HANDLE_MAX_LENGTH
        :too_long
      else
        :special_characters
      end
      # FIXME(project_handles): Add two further branches (checked after the above):
      #
      #   :handle_reserved  — identifier already in project_handles for another
      #                        project (any row, current or historical)
      #   :identifier_taken — identifier is valid format and will be auto-adopted
      #                        as another project's handle during migration
      #
      # Priority order: :too_long > :special_characters >
      #                 :handle_reserved > :identifier_taken
    end

    # Builds the suggestion list for a set of problematic projects.
    # Handles are generated in iteration order; duplicates are resolved in-place
    # so the final list is guaranteed to contain no two identical handles.
    def generate_suggestions(projects)
      # FIXME(project_handles): Pre-seed used_handles from the DB before iterating
      # so suggestions never collide with handles already in use across all projects:
      #
      #   used_handles.merge(ProjectHandle.pluck(:handle))
      #   # ^ every handle ever assigned to any project (current + historical)
      #   # → prevents :handle_reserved conflicts
      #
      #   used_handles.merge(
      #     Project.where("length(identifier) <= ? AND identifier ~ ?",
      #                   HANDLE_MAX_LENGTH, "^[A-Za-z0-9]+$")
      #            .pluck(:identifier)
      #   )
      #   # ^ valid-format identifiers that will be auto-adopted as handles
      #   # → prevents :identifier_taken conflicts
      used_handles = Set.new

      projects.map do |project|
        base   = handle_from_name(project.name)
        handle = unique_handle(base, used_handles)
        used_handles << handle

        {
          project:,
          current_identifier: project.identifier,
          suggested_handle: handle,
          error_reason: error_reason(project.identifier)
        }
      end
    end

    # Derives a short uppercase handle from the project name by taking the
    # first letter of each word (acronym style):
    #   "Flight Planning Algorithm" → "FPA"
    #   "Fly & Sky"                 → "FS"
    #   "Cécile Martin"             → "CM"  (accented letters treated as one word)
    # Falls back to "PROJ" when the name yields no usable initials.
    # Result is truncated to HANDLE_MAX_LENGTH characters.
    def handle_from_name(name)
      # Use POSIX [[:alpha:]] so accented letters (é, ñ, ü…) are kept inside
      # their word rather than treated as separators by the ASCII-only [a-zA-Z].
      words = name.to_s.scan(/[[:alpha:][:digit:]]+/)
      return FALLBACK_HANDLE if words.empty?

      # Transliterate each word's first character to ASCII (é→e, ñ→n) then
      # upcase. filter_map silently drops any initial that yields nothing useful
      # after transliteration (e.g. a lone ideograph that maps to "?").
      acronym = words.filter_map do |word|
        ch = I18n.with_locale(:en) { I18n.transliterate(word[0]) }.upcase[0]
        ch if ch&.match?(/\A[A-Z0-9]\z/)
      end.join

      return FALLBACK_HANDLE if acronym.empty?

      acronym.slice(0, HANDLE_MAX_LENGTH)
    end

    # Ensures the returned handle is unique within the current batch by appending
    # an incrementing numeric suffix when the base acronym is already taken.
    #
    # Examples (HANDLE_MAX_LENGTH = 10):
    #   unique_handle("SC",         Set["SC"])         → "SC2"
    #   unique_handle("SC",         Set["SC", "SC2"])  → "SC3"
    #   unique_handle("ABCDEFGHIJ", Set["ABCDEFGHIJ"]) → "ABCDEFGHI2"
    #     (base is trimmed so base + suffix ≤ HANDLE_MAX_LENGTH)
    #
    # @param base [String] the acronym to start from (already ≤ HANDLE_MAX_LENGTH)
    # @param used_handles [Set<String>] handles already assigned in this batch
    # @return [String] a unique handle ≤ HANDLE_MAX_LENGTH
    # @raise [RuntimeError] if no unique candidate is found within SUFFIX_LIMIT
    def unique_handle(base, used_handles)
      # Fast path: acronym is unique, no suffix needed.
      return base unless used_handles.include?(base)

      # Slow path: append "2", "3", … trimming the base as needed so the result
      # never exceeds HANDLE_MAX_LENGTH characters.
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
  end
end
