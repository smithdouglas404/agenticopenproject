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

# Reallocates semantic identifiers when work packages move between projects.
#
# Uses 3 bulk SQL statements (regardless of work package count):
#   1. Records moves in work_package_moves (so old identifiers remain resolvable)
#   2. Reserves a block of sequence numbers from the target project's counter cache
#   3. Bulk-updates all work packages with new identifiers in a single CTE-based UPDATE
#
# Old identifiers are resolved at read time via compute-on-read finder methods
# that check the work_package_moves table as a fallback.
#
# All operations run within a single advisory lock on the target project
# to serialize sequence allocation.
class WorkPackages::ReallocateIdentifiersOnMoveService
  attr_reader :target_project, :source_project_id

  # @param target_project [Project] the project being moved into
  # @param source_project_id [Integer] the project being moved from (passed explicitly
  #   because descendants loaded fresh in cleanup have no dirty tracking)
  def initialize(target_project:, source_project_id:)
    @target_project = target_project
    @source_project_id = source_project_id
  end

  def call(moved_work_packages)
    return unless Setting::WorkPackageIdentifier.alphanumeric?

    wp_data = moved_work_packages
                .select { it.identifier.present? }
                .map { [it.id, sequence_number_from(it)] }
                .select { it[1] }
    return if wp_data.empty?

    OpenProject::Mutex.with_advisory_lock_transaction(target_project, "wp_sequence") do
      record_moves(wp_data)
      base_seq = reserve_sequence_block!(wp_data.size)
      bulk_update_identifiers(wp_data.map(&:first), base_seq)
    end
  end

  private

  # Extracts the old sequence number from dirty tracking or the identifier string.
  # Descendants loaded fresh from DB after bulk-update don't have dirty tracking,
  # so we fall back to parsing the identifier (format: "PREFIX-SEQ").
  def sequence_number_from(work_package)
    work_package.sequence_number_before_last_save || parse_sequence_from_identifier(work_package.identifier)
  end

  def parse_sequence_from_identifier(identifier)
    identifier&.match(/-(\d+)\z/) { it[1].to_i }
  end

  def record_moves(wp_data)
    now = Time.current
    WorkPackageMove.insert_all(
      wp_data.map do |wp_id, seq|
        { work_package_id: wp_id, source_project_id:, sequence_number: seq, created_at: now }
      end,
      unique_by: %i[source_project_id sequence_number]
    )
  end

  def reserve_sequence_block!(count)
    final_seq = connection.select_value(<<~SQL.squish)
      UPDATE projects
      SET wp_sequence_counter = wp_sequence_counter + #{count}
      WHERE id = #{target_project.id}
      RETURNING wp_sequence_counter
    SQL

    final_seq - count
  end

  # Assigns sequential identifiers to moved work packages in a single SQL statement.
  #
  # Uses a CTE with unnest(...) WITH ORDINALITY to expand the wp_ids array into
  # (id, position) pairs, preserving input order. Each work package gets:
  #   sequence_number = base_seq + position
  #   identifier      = "PREFIX-{sequence_number}"
  def bulk_update_identifiers(wp_ids, base_seq)
    ids_array = "{#{wp_ids.map { |id| Integer(id) }.join(',')}}"
    prefix = connection.quote(target_project.identifier)

    connection.execute(<<~SQL.squish)
      WITH numbered AS (
        SELECT id, ordinality AS rn
        FROM unnest(#{connection.quote(ids_array)}::bigint[]) WITH ORDINALITY AS t(id, ordinality)
      )
      UPDATE work_packages
      SET sequence_number = #{base_seq} + numbered.rn,
          identifier = #{prefix} || '-' || CAST((#{base_seq} + numbered.rn) AS text)
      FROM numbered
      WHERE work_packages.id = numbered.id
    SQL
  end

  delegate :connection, to: OpenProject::SqlSanitization, private: true
end
