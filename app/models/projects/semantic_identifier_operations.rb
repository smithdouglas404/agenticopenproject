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

module Projects::SemanticIdentifierOperations
  extend ActiveSupport::Concern

  # Returns all identifiers this project has ever used, as recorded by FriendlyId
  # (includes the current identifier and every historical one).
  def semantic_identifier_aliases
    FriendlyId::Slug.where(sluggable_type: Project.name, sluggable_id: id).pluck(:slug)
  end

  # Atomically allocates the next sequence number for a work package in this project
  # and returns it paired with the resulting semantic identifier (e.g. [42, "PROJ-42"]).
  # Uses a row-level lock to prevent concurrent WP creation from getting the same number.
  def allocate_wp_semantic_identifier!
    seq = with_lock do
      increment!(:wp_sequence_counter)
      wp_sequence_counter
    end
    [seq, "#{identifier}-#{seq}"]
  end

  # Called after this project's identifier is renamed. Atomically:
  # 1. Appends new-prefix aliases for every WP that ever carried an old-prefix alias.
  # 2. Updates identifier on resident WPs to the new prefix.
  def handle_semantic_rename(old_identifier)
    like_pattern = "#{self.class.sanitize_sql_like(old_identifier)}-%"
    prefix = "#{old_identifier}-"
    new_prefix = "#{identifier}-"

    WorkPackageSemanticAlias.transaction do
      append_aliases_with_new_prefix(like_pattern, prefix, new_prefix)
      rewrite_semantic_ids(like_pattern, prefix, new_prefix)
    end
  end

  private

  def append_aliases_with_new_prefix(like_pattern, prefix, new_prefix)
    WorkPackageSemanticAlias
      .where("identifier LIKE ?", like_pattern)
      .in_batches do |relation|
        rows = relation
                 .pluck(:work_package_id, :identifier)
                 .map { |wp_id, id| { identifier: new_prefix + id.delete_prefix(prefix), work_package_id: wp_id } }
        WorkPackageSemanticAlias.insert_all(rows, unique_by: :identifier) if rows.any?
      end
  end

  def rewrite_semantic_ids(like_pattern, prefix, new_prefix)
    WorkPackage
      .where("identifier LIKE ?", like_pattern)
      .update_all(["identifier = REPLACE(identifier, ?, ?)", prefix, new_prefix])
  end
end
