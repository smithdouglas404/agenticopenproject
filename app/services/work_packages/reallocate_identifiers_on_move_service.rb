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
#   1. Reserves a block of sequence numbers from the target project's counter cache
#   2. Records old identifiers in FriendlyId slug history (so they remain resolvable)
#   3. Bulk-updates all work packages with new identifiers in a single CTE-based UPDATE
#
# Old identifiers are recorded manually because bulk SQL bypasses ActiveRecord
# callbacks, so FriendlyId's automatic slug history tracking does not fire.
#
# All operations run within a single advisory lock on the target project
# to serialize sequence allocation.
class WorkPackages::ReallocateIdentifiersOnMoveService
  attr_reader :target_project

  def initialize(target_project:)
    @target_project = target_project
  end

  def call(moved_work_packages)
    return unless Setting::WorkPackageIdentifier.alphanumeric?

    wp_data = extract_wp_data(moved_work_packages)
    return if wp_data.empty?

    OpenProject::Mutex.with_advisory_lock_transaction(target_project, "wp_sequence") do
      base_seq = reserve_sequence_block!(wp_data.size)
      record_old_slugs(wp_data)
      record_moves(wp_data)
      bulk_update_identifiers(wp_data.map(&:first), base_seq)
    end
  end

  private

  def extract_wp_data(moved_work_packages)
    moved_work_packages
      .select { |wp| wp.identifier.present? }
      .map { |wp| [wp.id, wp.identifier] }
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

  def record_old_slugs(wp_data)
    now = Time.current
    FriendlyId::Slug.insert_all(
      wp_data.map do |wp_id, old_identifier|
        { sluggable_type: WorkPackage.name, sluggable_id: wp_id, slug: old_identifier, scope: nil, created_at: now }
      end,
      unique_by: %i[slug sluggable_type scope]
    )
  end

  # Records structural bindings (project_id + sequence_number) for moved work packages
  # so that ghost identifier resolution can find WPs that have left a project.
  #
  # The old identifier is parsed to extract the source project and sequence number,
  # avoiding reliance on ActiveRecord dirty-tracking attributes which may not be
  # available for descendant WPs in a hierarchy move.
  def record_moves(wp_data)
    now = Time.current
    rows = wp_data.filter_map do |wp_id, old_identifier|
      prefix, seq = old_identifier.match(/\A(.+)-(\d+)\z/)&.captures
      next unless prefix && seq

      source_project = Project.find_by(identifier: prefix)
      next unless source_project

      { work_package_id: wp_id, project_id: source_project.id,
        sequence_number: seq.to_i, created_at: now }
    end

    WorkPackageMove.insert_all(rows, unique_by: %i[project_id sequence_number]) if rows.any?
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
