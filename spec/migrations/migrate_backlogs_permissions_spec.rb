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

require "spec_helper"
require Rails.root.join("db/migrate/20260212145213_migrate_backlogs_permissions")

RSpec.describe MigrateBacklogsPermissions, type: :model do
  subject(:migrate) { ActiveRecord::Migration.suppress_messages { described_class.migrate(:up) } }

  let!(:empty_role) { create(:project_role) }
  # Using add_public_permissions: false to keep permission sets minimal.
  let!(:backlog_viewer_role) do
    create(:project_role, permissions: %i[view_master_backlog], add_public_permissions: false)
  end
  let!(:taskboard_viewer_role) do
    create(:project_role, permissions: %i[view_taskboards], add_public_permissions: false)
  end
  let(:member_role_permissions) do
    %i[view_master_backlog view_taskboards add_work_packages
       edit_work_packages assign_versions]
  end
  let(:migrated_member_role_permissions) do
    %i[add_work_packages edit_work_packages assign_versions view_sprints manage_sprint_items]
  end
  let!(:member_role) do
    create(:project_role, permissions: member_role_permissions, add_public_permissions: false)
  end
  let(:manager_role_permissions) do
    %i[view_master_backlog view_taskboards manage_versions select_done_statuses
       update_sprints assign_versions add_work_packages edit_work_packages]
  end
  let(:migrated_manager_role_permissions) do
    %i[manage_versions add_work_packages edit_work_packages assign_versions
       view_sprints create_sprints manage_sprint_items]
  end
  let!(:manager_role) do
    create(:project_role, permissions: manager_role_permissions, add_public_permissions: false)
  end

  describe "migrating up" do
    it "does not add any permissions to a role without backlogs permissions" do
      expect { migrate }.not_to change { empty_role.reload.permissions }
    end

    it "migrates manager_role permissions correctly" do
      expect { migrate }
        .to change { manager_role.reload.permissions }
        .from(match_array(manager_role_permissions))
        .to(match_array(migrated_manager_role_permissions))
    end

    it "migrates backlog_viewer_role permissions correctly" do
      expect { migrate }
        .to change { backlog_viewer_role.reload.permissions }
        .from(match_array(%i[view_master_backlog]))
        .to(match_array(%i[view_sprints]))
    end

    it "migrates taskboard_viewer_role permissions correctly" do
      expect { migrate }
        .to change { taskboard_viewer_role.reload.permissions }
        .from(match_array(%i[view_taskboards]))
        .to(match_array(%i[view_sprints]))
    end

    it "migrates member_role permissions correctly" do
      expect { migrate }
        .to change { member_role.reload.permissions }
        .from(match_array(member_role_permissions))
        .to(match_array(migrated_member_role_permissions))
    end

    it "does not duplicate view_sprints when role had both view_master_backlog and view_taskboards" do
      migrate
      expect(manager_role.reload.role_permissions.where(permission: "view_sprints").count).to eq(1)
    end

    it "does not duplicate create_sprints when role has multiple source permissions" do
      migrate
      expect(manager_role.reload.role_permissions.where(permission: "create_sprints").count).to eq(1)
    end

    it "does not duplicate manage_sprint_items when role has multiple source permissions" do
      migrate
      expect(manager_role.reload.role_permissions.where(permission: "manage_sprint_items").count).to eq(1)
    end
  end

  describe "migrating down" do
    subject(:rollback) { ActiveRecord::Migration.suppress_messages { described_class.migrate(:down) } }

    before { migrate }

    it "reverts backlog_viewer_role permissions" do
      expect { rollback }
        .to change { backlog_viewer_role.reload.permissions }
        .from(match_array(%i[view_sprints]))
        .to(match_array(%i[view_taskboards view_master_backlog]))
    end

    it "reverts manager_role permissions" do
      expect { rollback }
        .to change { manager_role.reload.permissions }
        .from(match_array(migrated_manager_role_permissions))
        .to(match_array(manager_role_permissions))
    end

    it "reverts member_role permissions" do
      expect { rollback }
        .to change { member_role.reload.permissions }
        .from(match_array(migrated_member_role_permissions))
        .to(match_array(member_role_permissions))
    end
  end
end
