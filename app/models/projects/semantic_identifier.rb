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

module Projects::SemanticIdentifier
  extend ActiveSupport::Concern

  # Atomically allocates the next sequence number for a work package in this project
  # and returns it paired with the resulting semantic identifier (e.g. [42, "PROJ-42"]).
  # Uses an advisory lock scoped to this project to serialize concurrent allocations
  # without blocking unrelated project row writes.
  def allocate_wp_semantic_identifier!
    seq = OpenProject::Mutex.with_advisory_lock(
      self.class,
      "wp_sequence_#{id}"
    ) do
      self.class.connection.select_value(<<~SQL.squish)
        UPDATE projects
        SET wp_sequence_counter = wp_sequence_counter + 1
        WHERE id = #{self.class.connection.quote(id)}
        RETURNING wp_sequence_counter
      SQL
    end

    [seq, "#{identifier}-#{seq}"]
  end

  # Called after this project's identifier is renamed. Atomically:
  # 1. Appends new-prefix aliases for every WP that ever carried an old-prefix alias.
  # 2. Updates identifier on resident WPs to the new prefix.
  def handle_semantic_rename(old_identifier, batch_size: 1000)
    like_pattern = "#{self.class.sanitize_sql_like(old_identifier)}-%"
    prefix = "#{old_identifier}-"
    new_prefix = "#{identifier}-"

    WorkPackageSemanticAlias.transaction do
      append_aliases_with_new_prefix(like_pattern:, prefix:, new_prefix:, batch_size:)
      rewrite_semantic_ids(like_pattern:, prefix:, new_prefix:, batch_size:)
    end
  end

  private

  # For every alias row whose identifier starts with the old prefix, inserts a
  # corresponding row with the new prefix. This covers WPs still in the project
  # as well as any that have moved out but still carry old-prefix alias rows.
  def append_aliases_with_new_prefix(like_pattern:, prefix:, new_prefix:, batch_size:)
    WorkPackageSemanticAlias
      .where("identifier LIKE ?", like_pattern)
      .in_batches(of: batch_size) do |relation|
        now = Time.current
        WorkPackageSemanticAlias.connection.execute(
          WorkPackageSemanticAlias.sanitize_sql([<<~SQL.squish, { prefix:, new_prefix:, now: }])
            INSERT INTO work_package_semantic_aliases (identifier, work_package_id, created_at, updated_at)
            SELECT REPLACE(identifier, :prefix, :new_prefix), work_package_id, :now, :now
            FROM (#{relation.to_sql}) AS batch
            ON CONFLICT (identifier) DO NOTHING
          SQL
        )
      end
  end

  # Updates the identifier column on all resident WPs to replace the old prefix with the new one.
  def rewrite_semantic_ids(like_pattern:, prefix:, new_prefix:, batch_size:)
    WorkPackage
      .where("identifier LIKE ?", like_pattern)
      .in_batches(of: batch_size) do |relation|
        relation.update_all(["identifier = REPLACE(identifier, ?, ?)", prefix, new_prefix])
      end
  end
end
