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
# Foundation, Inc., 51 Franklin Street, Bristol, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

# Registry entry mapping a semantic identifier (e.g. "PROJ-42") to a work package.
# Rows are append-only during a WP's lifetime — historic identifiers are never deleted
# on moves or renames, enabling resolution of any identifier a WP has ever carried.
# All rows are removed when the work package itself is deleted (cascade via FK).
# The current identifier is stored directly on work_packages.semantic_id.
#
# Class methods provide the write side of the registry:
#   WorkPackageSemanticAlias.register_move(wp)                       # on WP project change
#   WorkPackageSemanticAlias.register_project_rename(proj, old_id)   # on project identifier change
#
# Initial registration on WP creation is handled by WorkPackage::SemanticIdentifier#register_semantic_id (after_create).
class WorkPackageSemanticAlias < ApplicationRecord
  belongs_to :work_package, inverse_of: :semantic_aliases

  validates :identifier, presence: true, uniqueness: true
  validates :work_package, presence: true

  # Called after a WP moves to a different project. Appends a new registry entry
  # in the target project's namespace and updates semantic_id on the work package.
  def self.register_move(work_package)
    transaction do
      seq, sid = work_package.project.allocate_wp_semantic_identifier!
      work_package.update_columns(sequence_number: seq, semantic_id: sid)
      create!(identifier: sid, work_package_id: work_package.id)
    end
  end

  # Called after a project identifier rename. Bulk-inserts new-prefix registry entries
  # for every WP that ever appeared in this project (including ones that have since moved away),
  # and updates semantic_id on WPs still resident in the project.
  # insert_all with unique_by: :identifier skips rows that already exist,
  # making the operation idempotent and safe under concurrency.
  def self.register_project_rename(project, old_identifier)
    like_pattern = "#{sanitize_sql_like(old_identifier)}-%"

    transaction do
      rows = build_rename_rows(project, old_identifier, like_pattern)
      insert_all(rows, unique_by: :identifier) if rows.any?

      # Update semantic_id only on WPs whose current identifier still carries the old prefix
      # (i.e. they are still resident in the project — WPs that have moved away already
      # have a different semantic_id and must not be touched here).
      WorkPackage.where("semantic_id LIKE ?", like_pattern).find_each do |wp|
        seq = wp.semantic_id.delete_prefix("#{old_identifier}-")
        wp.update_columns(semantic_id: "#{project.identifier}-#{seq}")
      end
    end
  end

  private_class_method def self.build_rename_rows(project, old_identifier, like_pattern)
    where("identifier LIKE ?", like_pattern)
      .pluck(:work_package_id, :identifier)
      .map do |wp_id, id|
        { identifier: "#{project.identifier}-#{id.delete_prefix("#{old_identifier}-")}",
          work_package_id: wp_id }
      end
  end

end
