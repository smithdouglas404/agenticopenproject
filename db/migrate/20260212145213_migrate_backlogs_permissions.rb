# frozen_string_literal: true

require Rails.root.join("db/migrate/migration_utils/permission_renamer")
require Rails.root.join("db/migrate/migration_utils/permission_adder")

class MigrateBacklogsPermissions < ActiveRecord::Migration[8.1]
  def up
    ::Migration::MigrationUtils::PermissionRenamer.rename(:view_master_backlog, :view_sprints)

    # TODO: This could also use the PermissionRenamer.rename, but since that method is using an
    # SQL update query, we can potentially end up having duplicate permissions defined,
    # if a user has both view_master_backlog and view_taskboards.
    ::Migration::MigrationUtils::PermissionAdder.add(:view_taskboards, :view_sprints)
    RolePermission.delete_by(permission: "view_taskboards")

    ::Migration::MigrationUtils::PermissionAdder.add(:manage_versions, :create_sprints)
    ::Migration::MigrationUtils::PermissionAdder.add(:select_done_statuses, :create_sprints)
    ::Migration::MigrationUtils::PermissionAdder.add(:update_sprints, :create_sprints)

    RolePermission.delete_by(permission: %w(update_sprints select_done_statuses))

    ::Migration::MigrationUtils::PermissionAdder.add(:assign_versions, :manage_sprint_items)
    ::Migration::MigrationUtils::PermissionAdder.add(:add_work_packages, :manage_sprint_items)
    ::Migration::MigrationUtils::PermissionAdder.add(:edit_work_packages, :manage_sprint_items)
  end

  def down
    ::Migration::MigrationUtils::PermissionAdder.add(:view_sprints, :view_taskboards, force: true)
    ::Migration::MigrationUtils::PermissionRenamer.rename("view_sprints", "view_master_backlog")

    # Note: Some roles might receive extra permissions on the way down because,
    # we need to add back all the roles that have been merged on the way up.
    ::Migration::MigrationUtils::PermissionAdder.add(:create_sprints, :manage_versions)
    ::Migration::MigrationUtils::PermissionAdder.add(:create_sprints, :select_done_statuses, force: true)
    ::Migration::MigrationUtils::PermissionAdder.add(:create_sprints, :update_sprints, force: true)

    ::Migration::MigrationUtils::PermissionAdder.add(:manage_sprint_items, :assign_versions)
    ::Migration::MigrationUtils::PermissionAdder.add(:manage_sprint_items, :add_work_packages)
    ::Migration::MigrationUtils::PermissionAdder.add(:manage_sprint_items, :edit_work_packages)

    # Remove new permissions that were added during up
    RolePermission.delete_by(permission: %w(create_sprints manage_sprint_items))
  end
end
