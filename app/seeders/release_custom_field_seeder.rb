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

# Provisions the "Release" work package custom field so the Release feature is usable
# out of the box: a multi-value version field scoped to release versions
# (version_kind: "release"), available in all projects and on all work package types.
#
# Idempotent: only seeds when no release version custom field exists yet, so it never
# duplicates the field or overrides an administrator's own configuration.
class ReleaseCustomFieldSeeder < Seeder
  def seed_data!
    custom_field = WorkPackageCustomField.create!(
      name: "Release",
      field_format: "version",
      version_kind: "release",
      multi_value: true,
      is_for_all: true,
      is_required: false
    )
    custom_field.types = Type.all.to_a

    print_status "    ✓ Created the Release work package custom field"
  end

  def applicable?
    WorkPackageCustomField.where(field_format: "version", version_kind: "release").none?
  end

  def not_applicable_message
    "No need to seed the Release custom field as a release version custom field already exists."
  end
end
