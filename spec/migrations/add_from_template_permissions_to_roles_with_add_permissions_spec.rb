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
require Rails.root.join("db/migrate/20251113124140_add_from_template_permissions_to_roles_with_add_permissions")

RSpec.describe AddFromTemplatePermissionsToRolesWithAddPermissions, type: :model do
  let(:direction) { :up }

  def run_migration
    # Silencing migration logs, since we are not interested in that during testing
    ActiveRecord::Migration.suppress_messages { described_class.migrate(direction) }
  end

  shared_examples_for "not changing permissions" do
    it "is not changed" do
      expect { run_migration }.not_to change { role.reload.permissions }
    end

    it "does not add any new permissions" do
      expect { run_migration }.not_to change(RolePermission, :count)
    end
  end

  shared_examples_for "migration is idempotent" do
    context "when the migration is run twice" do
      before { run_migration }

      it_behaves_like "not changing permissions"
    end
  end

  shared_examples_for "adding permissions" do |new_permissions|
    it "adds the #{new_permissions} permissions for the role" do
      expect { run_migration }.to change { role.reload.permissions }
        .from(match_array(permissions))
        .to(match_array(permissions + new_permissions))
    end
  end

  context "for a role not eligible for from_template permissions" do
    let(:permissions) { %i[view_project permission1 permission2] }
    let!(:role) { create(:global_role, permissions:) }

    it_behaves_like "not changing permissions"
    it_behaves_like "migration is idempotent"
  end

  context "for a role eligible for :add_project_from_template" do
    let(:permissions) { %i[add_project permission1 permission2] }
    let!(:role) { create(:global_role, permissions:) }

    it_behaves_like "adding permissions", %i[add_project_from_template]
    it_behaves_like "migration is idempotent"
  end

  context "for a role that already has :add_project_from_template" do
    let(:permissions) { %i[add_project add_project_from_template permission1 permission2] }
    let!(:role) { create(:global_role, permissions:) }

    it_behaves_like "not changing permissions"
    it_behaves_like "migration is idempotent"
  end

  context "for a role eligible for :add_programs_from_template" do
    let(:permissions) { %i[add_programs permission1 permission2] }
    let!(:role) { create(:global_role, permissions:) }

    it_behaves_like "adding permissions", %i[add_programs_from_template]
    it_behaves_like "migration is idempotent"
  end

  context "for a role that already has :add_programs_from_template" do
    let(:permissions) { %i[add_programs add_programs_from_template permission1 permission2] }
    let!(:role) { create(:global_role, permissions:) }

    it_behaves_like "not changing permissions"
    it_behaves_like "migration is idempotent"
  end

  context "for a role eligible for :add_portfolios_from_template" do
    let(:permissions) { %i[add_portfolios permission1 permission2] }
    let!(:role) { create(:global_role, permissions:) }

    it_behaves_like "adding permissions", %i[add_portfolios_from_template]
    it_behaves_like "migration is idempotent"
  end

  context "for a role that already has :add_portfolios_from_template" do
    let(:permissions) { %i[add_portfolios add_portfolios_from_template permission1 permission2] }
    let!(:role) { create(:global_role, permissions:) }

    it_behaves_like "not changing permissions"
    it_behaves_like "migration is idempotent"
  end

  context "for a role eligible for all three from_template permissions" do
    let(:permissions) { %i[add_project add_programs add_portfolios permission1 permission2] }
    let!(:role) { create(:global_role, permissions:) }

    it_behaves_like "adding permissions", %i[add_project_from_template add_programs_from_template add_portfolios_from_template]
    it_behaves_like "migration is idempotent"
  end

  context "for a role eligible for all three but already has some from_template permissions" do
    let(:permissions) do
      %i[add_project add_project_from_template add_programs add_portfolios permission1 permission2]
    end
    let!(:role) { create(:global_role, permissions:) }

    it_behaves_like "adding permissions", %i[add_programs_from_template add_portfolios_from_template]
    it_behaves_like "migration is idempotent"
  end

  context "for non-member role with :add_project permission" do
    # Non-member and anonymous roles get public permissions by default
    let(:public_permissions) { OpenProject::AccessControl.public_permissions.map(&:name) }
    let(:permissions) { %i[add_project permission1] }
    let!(:role) { create(:non_member, permissions:) }

    it "adds :add_project_from_template permission" do
      expect { run_migration }.to change { role.reload.permissions }
        .from(match_array(permissions + public_permissions))
        .to match_array(permissions + public_permissions + [:add_project_from_template])
    end

    it_behaves_like "migration is idempotent"
  end

  context "for anonymous role with :add_project permission" do
    let(:permissions) { %i[add_project permission1] }
    let!(:role) { create(:anonymous_role, permissions:) }

    # Anonymous role should not get the permission due to require: :loggedin
    it "does not add the permission due to require: :loggedin constraint" do
      expect { run_migration }.not_to change { role.reload.permissions }
    end

    it_behaves_like "migration is idempotent"
  end

  describe "down migration" do
    let(:direction) { :down }

    let(:permissions) do
      %i[add_project add_project_from_template
         add_programs add_programs_from_template
         add_portfolios add_portfolios_from_template]
    end
    let!(:role) { create(:global_role, permissions:) }

    it "removes all from_template permissions" do
      expect { run_migration }.to change { role.reload.permissions }
        .from(match_array(permissions))
        .to match_array(%i[add_project add_programs add_portfolios])
    end

    context "when running down migration twice" do
      before { run_migration }

      it "does not raise an error" do
        expect { run_migration }.not_to raise_error
      end

      it_behaves_like "not changing permissions"
    end

    context "when no from_template permissions exist" do
      let(:permissions) { %i[add_project add_programs add_portfolios] }

      it "does not raise an error" do
        expect { run_migration }.not_to raise_error
      end

      it_behaves_like "not changing permissions"
    end
  end
end
