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
# Rows are never deleted — historic identifiers remain with current: false.
#
# Class methods provide the write side of the registry:
#   WorkPackageSemanticId.register_move(wp)                       # on WP project change
#   WorkPackageSemanticId.register_project_rename(proj, old_id)   # on project identifier change
#
# Initial registration on WP creation is handled by WorkPackage::Identifier#register_semantic_id (after_create).
class WorkPackageSemanticId < ApplicationRecord
  belongs_to :work_package, inverse_of: :semantic_ids

  validates :identifier, presence: true, uniqueness: true
  validates :work_package, presence: true

  # Called after a WP moves to a different project. Retires the current entry
  # and inserts a new one in the target project's namespace.
  def self.register_move(work_package)
    project = work_package.project
    seq = allocate_sequence!(project)
    work_package.update_columns(sequence_number: seq)

    transaction do
      where(work_package_id: work_package.id, current: true).update_all(current: false)
      create!(identifier: "#{project.identifier}-#{seq}", work_package_id: work_package.id, current: true)
    end
  end

  # Called after a project identifier rename. Retires all current entries that
  # carry the old prefix and bulk-inserts new current entries for every WP that
  # ever appeared in this project (including ones that have since moved away).
  # insert_all with unique_by: :identifier skips rows that already exist,
  # making the operation idempotent and safe under concurrency.
  def self.register_project_rename(project, old_identifier)
    new_prefix = project.identifier
    like_pattern = "#{sanitize_like(old_identifier)}-%"

    transaction do
      # Capture which specific identifier was active per WP before retiring.
      # This is the only row that should become current:true under the new prefix;
      # all other old-prefix rows (e.g. from WPs that have since moved away) become
      # current:false so they still resolve but don't conflict with the WP's actual
      # current identifier in its new project.
      active_id_by_wp = where(current: true)
                          .where("identifier LIKE ?", like_pattern)
                          .pluck(:work_package_id, :identifier)
                          .to_h

      where(current: true)
        .where("identifier LIKE ?", like_pattern)
        .update_all(current: false)

      rows = where("identifier LIKE ?", like_pattern)
               .pluck(:work_package_id, :identifier)
               .map do |wp_id, id|
                 { identifier: "#{new_prefix}-#{id.delete_prefix("#{old_identifier}-")}",
                   work_package_id: wp_id,
                   current: active_id_by_wp[wp_id] == id }
               end

      insert_all(rows, unique_by: :identifier) if rows.any?
    end
  end

  private_class_method def self.allocate_sequence!(project)
    project.with_lock do
      project.increment!(:wp_sequence_counter)
      project.wp_sequence_counter
    end
  end

  # Escapes _ so it is treated as a literal character in a LIKE pattern.
  # Project identifiers can contain underscores; % and \ cannot appear in them.
  private_class_method def self.sanitize_like(str)
    str.gsub("_", "\\_")
  end
end
