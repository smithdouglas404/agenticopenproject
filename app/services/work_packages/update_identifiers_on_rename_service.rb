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

# Updates work package identifiers when a project is renamed.
#
# For each work package with an existing identifier:
# 1. Records the old identifier in FriendlyId slug history (so it remains resolvable)
# 2. Bulk-updates all identifiers to use the new project identifier prefix
#
# Uses 2 SQL statements regardless of work package count.
class WorkPackages::UpdateIdentifiersOnRenameService
  attr_reader :project

  def initialize(project:)
    @project = project
  end

  def call
    return unless Setting::WorkPackageIdentifier.alphanumeric?

    wp_data = project.work_packages.where.not(identifier: nil).pluck(:id, :identifier)
    return if wp_data.empty?

    record_old_identifiers_in_slug_history(wp_data)
    bulk_update_identifiers
  end

  private

  def bulk_update_identifiers
    project.work_packages.where.not(sequence_number: nil).update_all(
      ["identifier = ? || '-' || CAST(sequence_number AS text)", project.identifier]
    )
  end

  def record_old_identifiers_in_slug_history(wp_data)
    now = Time.current
    FriendlyId::Slug.insert_all(
      wp_data.map do |wp_id, old_id|
        { sluggable_type: "WorkPackage", sluggable_id: wp_id, slug: old_id, created_at: now }
      end
    )
  end
end
