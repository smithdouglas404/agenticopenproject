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
# 2. Links the old HistoricalWorkPackageIdentifier to its slug for auditability
# 3. Reserves a new sequence number in the target project
# 4. Updates the work package with the new identifier
#
# All operations run within a single advisory lock on the target project
# to serialize sequence allocation.
class WorkPackages::ReallocateIdentifiersOnMoveService
  attr_reader :target_project, :source_project_id

  def initialize(target_project:, source_project_id:)
    @target_project = target_project
    @source_project_id = source_project_id
  end

  def call(moved_work_packages)
    return unless Setting::WorkPackageIdentifier.alphanumeric?

    wps_with_identifiers = moved_work_packages.select { |work_package| work_package.identifier.present? }
    return if wps_with_identifiers.empty?

    OpenProject::Mutex.with_advisory_lock_transaction(target_project, "wp_sequence") do
      max_seq = HistoricalWorkPackageIdentifier
                  .where(project_id: target_project.id)
                  .maximum(:sequence_number).to_i

      wps_with_identifiers.each do |work_package|
        max_seq += 1
        reallocate_single(work_package, max_seq)
      end
    end
  end

  private

  def reallocate_single(work_package, new_seq)
    slug = record_old_slug(work_package)
    link_historical_record_to_slug(work_package, slug)
    reserve_new_sequence(work_package, new_seq)
    update_work_package(work_package, new_seq)
  end

  def record_old_slug(work_package)
    FriendlyId::Slug.create!(
      slug: work_package.identifier, sluggable_type: "WorkPackage", sluggable_id: work_package.id
    )
  end

  def link_historical_record_to_slug(work_package, slug)
    HistoricalWorkPackageIdentifier
      .find_by(work_package_id: work_package.id, project_id: source_project_id,
               sequence_number: work_package.sequence_number)
      &.update!(friendly_id_slug: slug)
  end

  def reserve_new_sequence(work_package, new_seq)
    HistoricalWorkPackageIdentifier.create!(
      project: target_project, work_package:, sequence_number: new_seq
    )
  end

  def update_work_package(work_package, new_seq)
    work_package.update_columns(
      sequence_number: new_seq,
      identifier: "#{target_project.identifier}-#{new_seq}"
    )
  end
end
