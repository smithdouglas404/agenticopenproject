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
require Rails.root.join("db/migrate/migration_utils/permission_adder")

class AddNewSprintPermissionsToRoles < ActiveRecord::Migration[8.0]
  def up
    # These new Sprint permissions will eventually replace the old ones. Adding the new permissions here,
    # the old ones will be removed later.
    # view_master_backlog -> view_sprints
    add_permission_to_roles_with(:view_master_backlog, :view_sprints)

    # view_taskboards -> view_sprints
    add_permission_to_roles_with(:view_taskboards, :view_sprints)

    # update_sprints -> manage_sprints
    add_permission_to_roles_with(:update_sprints, :manage_sprints)
  end

  def down
    # Remove the new permissions (but keep the old ones)
    RolePermission.where(permission: %w[view_sprints manage_sprints]).delete_all
  end

  private

  def add_permission_to_roles_with(old_permission, new_permission)
    ::Migration::MigrationUtils::PermissionAdder.add(old_permission, new_permission, force: true)
  end
end
