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
# For each moved work package with an existing identifier:
# 1. Records the old identifier in FriendlyId slug history (so it remains resolvable)
# 2. Allocates a new sequence number from the target project's counter cache
# 3. Updates the work package with the new identifier
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

    wps_with_identifiers = moved_work_packages.select { |work_package| work_package.identifier.present? }
    return if wps_with_identifiers.empty?

    OpenProject::Mutex.with_advisory_lock_transaction(target_project, "wp_sequence") do
      wps_with_identifiers.each do |work_package|
        record_old_slug(work_package)
        allocate_new_identifier(work_package)
      end
    end
  end

  private

  def record_old_slug(work_package)
    FriendlyId::Slug.create!(
      slug: work_package.identifier, sluggable_type: "WorkPackage", sluggable_id: work_package.id
    )
  end

  def allocate_new_identifier(work_package)
    next_seq = target_project.increment_wp_sequence!

    work_package.update_columns(
      sequence_number: next_seq,
      identifier: "#{target_project.identifier}-#{next_seq}"
    )
  end
end
