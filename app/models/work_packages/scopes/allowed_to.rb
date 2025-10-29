# frozen_string_literal: true

# -- copyright
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
# ++

module WorkPackages::Scopes
  module AllowedTo
    extend ActiveSupport::Concern

    class_methods do
      # Returns an ActiveRecord::Relation to find all work packages for which
      # +user+ has the given +permission+ either directly on the work package
      # or by the linked project
      def allowed_to(user, permission) # rubocop:disable Metrics/PerceivedComplexity
        permissions = Authorization.contextual_permissions(permission, :work_package, raise_on_unknown: true)

        return none if user.locked? || user.deleted?
        return none if permissions.empty?

        if user.admin? && permissions.all?(&:grant_to_admin?)
          admin_allowed_to(permissions)
        elsif user.anonymous?
          anonymous_allowed_to(user, permissions)
        elsif Setting.large_instance_wp_allowed_to_sql?
          logged_in_non_admin_allowed_to_large_instances(user, permissions)
        else
          logged_in_non_admin_allowed_to_small_instances(user, permissions)
        end
      end

      private

      def admin_allowed_to(permissions)
        where(id: allowed_to_admin_relation(permissions))
      end

      def anonymous_allowed_to(user, permissions)
        where(project_id: Project.allowed_to(user, permissions))
      end

      def logged_in_non_admin_allowed_to_small_instances(user, permissions)
        allowed_via_wp_membership = allowed_to_member_relation(user, permissions)
        allowed_via_project_membership = Project.unscoped.allowed_to(user, permissions)

        where(project_id: allowed_via_project_membership.select(:id))
          .or(where(id: allowed_via_wp_membership.select(arel_table[:id])))
      end

      def logged_in_non_admin_allowed_to_large_instances(user, permissions)
        # Get all projects a user has the permissions in.
        # Permissions can come from project memberships as well as entity/work_package memberships, in addition
        # to (UNION) potentially the non-member permissions.
        # This comes back with the columns
        # * id (of the project) - this column will always be set regardless of whether the membership is entity-specific or not.
        # * entity_id (of the work package) - this column can be null in case it is a project-wide membership.
        allowed_via_project_or_work_package_membership = Project
                                                           .unscoped
                                                           .allowed_to_member_union(user,
                                                                                    permissions,
                                                                                    entity_types: [WorkPackage.name])

        # Split the member projects into two distinct sets
        # for easier reference.
        entity_member_projects = Arel.sql(<<~SQL.squish)
          SELECT *
          FROM member_projects
          WHERE entity_id IS NOT NULL
        SQL

        project_member_projects = Arel.sql(<<~SQL.squish)
          SELECT *
          FROM member_projects
          WHERE entity_id IS NULL
        SQL

        # Remove those entries from before that are
        # * entity (WorkPackage) specific AND
        # * have the same project as a non-entity specific entry.
        # That is the case if a work package is shared with a user
        # while the user is already a member in the project.
        # Since the allowed_to filtering is already specific to the permissions, that removal is safe.
        entity_member_projects_without_duplicates = Arel.sql(<<~SQL.squish)
          SELECT * FROM entity_member_projects
          WHERE NOT EXISTS (
            SELECT 1 FROM project_member_projects
            WHERE project_member_projects.id = entity_member_projects.id
          )
        SQL

        # Take all work packages allowed by either project-wide or entity-specific membership.
        # But now remove all those that are in a project for which an entity-specific membership exists that is not
        # for that entity (work package).
        # An alternative way of formulating this would be by comparing
        # * That the project_id matches AND
        # * the entity_id matches OR the entity_id is null
        #  ```
        #   SELECT * from work_packages
        # 	WHERE EXISTS (
        # 	  SELECT 1 FROM allowed_projects projects
        #     WHERE projects.id = work_packages.project_id
        #     AND (projects.entity_id = work_packages.id OR projects.entity_id IS NULL)
        # 	)
        # ```
        # Postgresql however sometimes turns to a sequential scan with the query above.
        #
        # Index scans can still happen in the combination of the CTE with the check outside of the
        # CTEs for the existence of any record.
        # This is particularly likely in case AR.exists? is used which adds a LIMIT 1
        # to the query. In this case, there is a known shortcoming that PostgreSQL's query planner
        # will make poor choices
        # (https://www.postgresql.org/message-id/flat/CA%2BU5nMLbXfUT9cWDHJ3tpxjC3bTWqizBKqTwDgzebCB5bAGCgg%40mail.gmail.com).
        #
        # Once AR supports adding materialization hints (https://github.com/rails/rails/pull/54322), the inner
        # `allowed` CTE can be abandoned as it is only used for being able to provide such a hint.
        allowed_by_projects_and_work_packages = Arel.sql(<<~SQL.squish)
          WITH allowed AS MATERIALIZED (
            SELECT id from work_packages
            WHERE project_id in (SELECT id FROM member_projects)
            AND NOT EXISTS (
              SELECT 1 FROM entity_member_projects_without_duplicates
              WHERE entity_member_projects_without_duplicates.id = work_packages.project_id
              AND entity_member_projects_without_duplicates.entity_id != work_packages.id
            )
          )

          SELECT * from allowed
        SQL

        with(member_projects: Arel.sql(allowed_via_project_or_work_package_membership.to_sql),
             entity_member_projects:,
             project_member_projects:,
             entity_member_projects_without_duplicates:,
             allowed_by_projects_and_work_packages:)
          .where(<<~SQL.squish)
            EXISTS (
              SELECT 1
              FROM allowed_by_projects_and_work_packages
              WHERE work_packages.id = allowed_by_projects_and_work_packages.id
            )
          SQL
      end

      def allowed_to_admin_relation(permissions)
        unscoped
        .joins(:project)
        .joins(allowed_to_enabled_module_join(permissions))
          .where(Project.arel_table[:active].eq(true))
      end

      def allowed_to_member_relation(user, permissions)
        Member
          .joins(allowed_to_member_in_work_package_join)
          .joins(active_project_join)
          .joins(allowed_to_enabled_module_join(permissions))
          .joins(member_roles: :role)
          .joins(allowed_to_role_permission_join(permissions))
          .where(member_conditions(user))
      end

      def allowed_to_enabled_module_join(permissions) # rubocop:disable Metrics/AbcSize
        project_module = permissions.filter_map(&:project_module).uniq
        enabled_module_table = EnabledModule.arel_table
        projects_table = Project.arel_table

        if project_module.any?
          arel_table.join(enabled_module_table, Arel::Nodes::InnerJoin)
                    .on(projects_table[:id].eq(enabled_module_table[:project_id])
                          .and(enabled_module_table[:name].in(project_module))
                          .and(projects_table[:active].eq(true)))
                    .join_sources
        end
      end

      def allowed_to_role_permission_join(permissions) # rubocop:disable Metrics/AbcSize
        return if permissions.all?(&:public?)

        role_permissions_table = RolePermission.arel_table
        enabled_modules_table = EnabledModule.arel_table
        roles_table = Role.arel_table

        condition = permissions.inject(Arel::Nodes::False.new) do |or_condition, permission|
          permission_condition = role_permissions_table[:permission].eq(permission.name)

          if permission.project_module.present?
            permission_condition = permission_condition.and(enabled_modules_table[:name].eq(permission.project_module))
          end

          or_condition.or(permission_condition)
        end

        arel_table
          .join(role_permissions_table, Arel::Nodes::InnerJoin)
          .on(roles_table[:id].eq(role_permissions_table[:role_id])
                              .and(condition))
          .join_sources
      end

      def active_project_join
        projects_table = Project.arel_table
        arel_table
          .join(projects_table)
                  .on(projects_table[:active].eq(true)
                   .and(projects_table[:id].eq(arel_table[:project_id])))
                  .join_sources
      end

      def allowed_to_member_in_work_package_join
        members_table = Member.arel_table
        arel_table.join(arel_table)
        .on(members_table[:entity_id].eq(arel_table[:id]))
        .join_sources
      end

      def member_conditions(user)
        Member.arel_table[:user_id].eq(user.id)
        .and(Member.arel_table[:entity_type].eq(model_name.name))
      end
    end
  end
end
