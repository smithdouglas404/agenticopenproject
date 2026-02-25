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
  # requirements (too long or containing non-alphanumeric characters) and
  # generates a short uppercase acronym suggestion for each one.
  #
  # A "problematic" identifier is one that:
  #   - contains any character outside [a-zA-Z0-9], or
  #   - is longer than HANDLE_MAX_LENGTH (10) characters
  #
  # The suggestion is derived from the project name: taking the first letter of
  # each word and uppercasing ("Flight Planning Algorithm" → "FPA"). When two
  # projects produce the same acronym, a numeric suffix resolves the collision
  # ("SC", "SC2", "SC3", …).
  #
  # FIXME(project_handles): This class currently reads from the existing
  # Project#identifier column. Once the project_handles data model is available,
  # replace #call with:
  #
  #   ProjectHandle
  #     .select("project_handles.handle AS identifier, projects.id, projects.name")
  #     .joins(:project)
  #     .where(current: true)
  #     .where("length(handle) > ? OR handle ~ ?", HANDLE_MAX_LENGTH, "[^a-zA-Z0-9]")
  #     .to_a
  #     .then { |problematic| generate_suggestions(problematic) }
  #
  # The :current boolean on ProjectHandle marks the live handle; old handles are
  # retained so that existing URLs continue to resolve.
  class ProjectHandleSuggestionGenerator
    HANDLE_MAX_LENGTH = 10

    # @return [Array<Hash>] one entry per project with a problematic identifier:
    #   { project:, current_identifier:, suggested_handle:, error_reason: }
    #   error_reason is :too_long or :special_characters
    def self.call
      new.call
    end

    def call
      # FIXME(project_handles): Swap Project query for ProjectHandle query (see class doc above).
      # Only select the three columns we need to avoid loading large text/JSON attributes.
      Project
        .select(:id, :name, :identifier)
        .where("length(identifier) > ? OR identifier ~ ?", HANDLE_MAX_LENGTH, "[^a-zA-Z0-9]")
        .to_a
        .then { |problematic| generate_suggestions(problematic) }
    end

    private

    def error_reason(identifier)
      if identifier.length > HANDLE_MAX_LENGTH
        :too_long
      else
        :special_characters
      end
    end

    # Builds the suggestion list for a set of problematic projects.
    # Handles are generated in iteration order; duplicates are resolved in-place
    # so the final list is guaranteed to contain no two identical handles.
    def generate_suggestions(projects)
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
    # Falls back to "P" when the name yields no alphanumeric words.
    # Result is truncated to HANDLE_MAX_LENGTH characters.
    def handle_from_name(name)
      words = name.to_s.scan(/[a-zA-Z0-9]+/)
      return "P" if words.empty?

      acronym = words.map { |w| w[0] }.join.upcase # rubocop:disable Rails/Pluck
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
    def unique_handle(base, used_handles)
      # Fast path: acronym is unique, no suffix needed.
      return base unless used_handles.include?(base)

      # Slow path: append "2", "3", … trimming the base as needed so the result
      # never exceeds HANDLE_MAX_LENGTH characters.
      counter = 2
      loop do
        suffix    = counter.to_s
        candidate = "#{base.slice(0, HANDLE_MAX_LENGTH - suffix.length)}#{suffix}"
        break candidate unless used_handles.include?(candidate)

        counter += 1
      end
    end
  end
end
