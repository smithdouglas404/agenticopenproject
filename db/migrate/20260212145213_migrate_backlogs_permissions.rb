# frozen_string_literal: true

require Rails.root.join("db/migrate/migration_utils/permission_renamer")
require Rails.root.join("db/migrate/migration_utils/permission_adder")

class MigrateBacklogsPermissions < ActiveRecord::Migration[8.1]
  def up
    ::Migration::MigrationUtils::PermissionRenamer.rename(:view_master_backlog, :view_sprints)
    ::Migration::MigrationUtils::PermissionRenamer.rename(:view_taskboards, :view_sprints)

    ::Migration::MigrationUtils::PermissionAdder.add(:manage_versions, :create_sprints)
    ::Migration::MigrationUtils::PermissionRenamer.rename(:update_sprints, :create_sprints)

    ::Migration::MigrationUtils::PermissionAdder.add(:assign_versions, :manage_sprint_items)
  end

  def down
    # Note: Ideally the `:view_taskboards`, `:view_master_backlog`, `:manage_versions`,
    # `:update_sprints` permissions should be restored too, but unfortunately we cannot know
    #  which one lead to the user gaining `:view_sprints` or `:create_sprints` permissions.
    # There are 2 possible solutions for this issue:
    #   1. Grant both the `:view_taskboards`, `:view_master_backlog` where `:view_sprints` was granted.
    #      Respectively, grant `:manage_versions`, `:update_sprints` permissions where `:create_sprints`
    #      was granted. Unfortunately this leads to users gaining permissions they didn't possibly had
    #      before the migration.
    #   2. Grant none of the undecisible permissions, which leads to users losing permissions they had
    #      before the migration.
    #
    # The conservative approach here is to pick #2, because it avoids accidentally leaking permissions
    # to users.

    # Remove new permissions that were added during the up migration
    RolePermission.delete_by(permission: %w(view_sprints create_sprints manage_sprint_items))
  end
end
