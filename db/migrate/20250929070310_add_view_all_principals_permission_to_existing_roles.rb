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

class AddViewAllPrincipalsPermissionToExistingRoles < ActiveRecord::Migration[8.0]
  def up
    # Add global role "View all users (migration)"
    global_role_view_all_users

    # Add the view_all_users permission to this role
    unless global_role_view_all_users.has_permission?(:view_all_principals)
      global_role_view_all_users.add_permission!(:view_all_principals)
    end

    # Grant "View all users" permission to all global roles that currently have "Manage user" permission
    # This ensures Edit users has dependency on View users
    add_permission_to_manage_user_roles

    # For project roles with "manage_members", create a global role with "view_all_users"
    # and assign it to users who have those project roles
    add_global_role_for_manage_members
  end

  def down
    # Remove "View all users" permission from all global roles
    GlobalRole.joins(:role_permissions)
              .where(role_permissions: { permission: :view_all_principals })
              .find_each do |role|
      role.remove_permission!(:view_all_principals)
    end

    remove_global_role_members
    global_role_view_all_users.destroy
  end

  private

  def add_global_role_for_manage_members
    service = Members::AddRoleService.new(current_user: User.system)
    role_id = global_role_view_all_users.id

    process_users(service, role_id)
    process_groups(role_id)
  end

  # Groups cannot use AddRoleService/CreateService here: post_process queries group_details,
  # which is created in a later migration. Assign the global member directly, then propagate
  # to direct group members (no descendant groups before group_details exists).
  def process_groups(role_id)
    principal_ids_with_manage_members("Group").each do |group_id|
      group = Group.find(group_id)
      member = ensure_global_member_for_group(group, role_id)
      propagate_global_group_role_to_users(group, member)
    end
  end

  def process_users(service, role_id)
    principal_ids_with_manage_members("User").each do |user_id|
      service
        .call(user_id:, role_id:, project_id: nil, send_notifications: false)
        .on_failure { |result| Rails.logger.error("Failed to assign global role to user #{user_id}: #{result.message}") }
    end
  end

  # PlaceholderUser and AnonymousUser must not receive global roles.
  def principal_ids_with_manage_members(principal_type)
    project_roles_with_manage_members = ProjectRole.joins(:role_permissions)
                                                   .where(role_permissions: { permission: "manage_members" })
                                                   .distinct

    return [] if project_roles_with_manage_members.empty?

    Member.joins(:principal, member_roles: :role)
          .where(member_roles: { roles: { id: project_roles_with_manage_members.pluck(:id) } })
          .where(users: { type: principal_type })
          .pluck(:user_id)
          .uniq
  end

  def ensure_global_member_for_group(group, role_id)
    Member.find_or_initialize_by(user_id: group.id, project_id: nil, entity: nil).tap do |member|
      member.member_roles.find_or_initialize_by(role_id: role_id, inherited_from: nil)
      member.save! if member.new_record? || member.member_roles.any?(&:new_record?)
    end
  end

  def propagate_global_group_role_to_users(group, member)
    Groups::CreateInheritedRolesService
      .new(group, current_user: User.system, contract_class: EmptyContract)
      .call(user_ids: group.user_ids, send_notifications: false, project_ids: nil)
      .on_failure do |result|
        Rails.logger.error("Failed to propagate global role for group #{member.user_id}: #{result.message}")
      end
  end

  def find_user_ids_with_view_all_users
    # Find all users who have manage_members permission in any project
    Member.joins(member_roles: :role)
          .where(project: nil, member_roles: { roles: { id: global_role_view_all_users.id } })
          .pluck(:user_id)
          .uniq
  end

  # Groups cannot use AddRoleService/CreateService here: post_process queries group_details,
  # which is created in a later migration. Assign the global member directly, then propagate
  # to direct group members (no descendant groups before group_details exists).
  def remove_global_role_members
    service = Members::RemoveRoleService.new(current_user: User.system)
    role_id = global_role_view_all_users.id

    principal_ids = find_user_ids_with_view_all_users
    group_ids = Group.where(id: principal_ids).pluck(:id)
    user_ids = principal_ids - group_ids

    remove_global_role_from_users(service, user_ids, role_id)
    group_ids.each do |group_id|
      remove_global_migration_role_from_group(group_id, role_id)
    end
  end

  def remove_global_role_from_users(service, user_ids, role_id)
    user_ids.each do |user_id|
      service
        .call(user_id:, role_id:, project_id: nil, send_notifications: false)
        .on_failure { |result| Rails.logger.error("Failed to remove global role from user #{user_id}: #{result.message}") }
    end
  end

  def remove_global_migration_role_from_group(group_id, role_id)
    member = Member.find_by(user_id: group_id, project_id: nil, entity: nil)
    return unless member

    member_role = member.member_roles.find_by(role_id:, inherited_from: nil)
    return unless member_role

    MemberRole.where(inherited_from: member_role.id).destroy_all
    member_role.destroy!
    member.destroy! if member.member_roles.reload.empty?
  end

  def global_role_view_all_users
    @global_role_view_all_users ||= GlobalRole.find_or_create_by(type: "GlobalRole", name: "View all users (migration)")
  end

  def add_permission_to_manage_user_roles
    ::Migration::MigrationUtils::PermissionAdder.add(:manage_user, :view_all_principals)
  end
end
