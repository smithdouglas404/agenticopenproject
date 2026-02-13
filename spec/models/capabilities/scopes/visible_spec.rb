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
require_relative "shared_examples"

RSpec.describe Capabilities::Scopes::Visible do
  # Use admin as current_user so that the default scope generates all capabilities
  # (Principal.visible for admin returns all principals). This isolates the visible
  # scope filtering from the default scope's principal filtering.
  shared_current_user do
    create(:admin)
  end

  subject(:scope) { Capability.visible(user).where(principal_id: other_user.id) }

  shared_let(:project) { create(:project, enabled_module_names: %i[]) }
  shared_let(:other_project) { create(:project, enabled_module_names: %i[]) }
  shared_let(:other_user) { create(:user) }

  let(:role) { create(:project_role, permissions: %i[manage_members]) }
  let(:global_role) { create(:global_role, permissions: %i[manage_user]) }

  let(:other_user_member) do
    create(:member,
           principal: other_user,
           roles: [role],
           project:)
  end
  let(:other_user_other_member) do
    create(:member,
           principal: other_user,
           roles: [role],
           project: other_project)
  end
  let(:other_user_global_member) do
    create(:global_member,
           principal: other_user,
           roles: [global_role])
  end

  before do
    other_user_member
    other_user_other_member
    other_user_global_member
  end

  describe ".visible" do
    context "with an admin user" do
      let(:user) { create(:admin) }

      include_examples "consists of contract actions", with: "all capabilities (project and global)" do
        let(:expected) do
          [
            ["memberships/create", other_user.id, project.id],
            ["memberships/update", other_user.id, project.id],
            ["memberships/destroy", other_user.id, project.id],
            ["memberships/create", other_user.id, other_project.id],
            ["memberships/update", other_user.id, other_project.id],
            ["memberships/destroy", other_user.id, other_project.id],
            ["users/read", other_user.id, nil],
            ["users/update", other_user.id, nil]
          ]
        end
      end
    end

    context "with a user having access to both projects" do
      let(:user) do
        create(:user,
               member_with_permissions: {
                 project => %i[manage_members],
                 other_project => %i[manage_members]
               })
      end

      include_examples "consists of contract actions", with: "all capabilities (project and global)" do
        let(:expected) do
          [
            ["memberships/create", other_user.id, project.id],
            ["memberships/update", other_user.id, project.id],
            ["memberships/destroy", other_user.id, project.id],
            ["memberships/create", other_user.id, other_project.id],
            ["memberships/update", other_user.id, other_project.id],
            ["memberships/destroy", other_user.id, other_project.id],
            ["users/read", other_user.id, nil],
            ["users/update", other_user.id, nil]
          ]
        end
      end
    end

    context "with a user having access to only one project" do
      let(:user) do
        create(:user,
               member_with_permissions: { project => %i[manage_members] })
      end

      include_examples "consists of contract actions", with: "only capabilities of that one project and global" do
        let(:expected) do
          [
            ["memberships/create", other_user.id, project.id],
            ["memberships/update", other_user.id, project.id],
            ["memberships/destroy", other_user.id, project.id],
            ["users/read", other_user.id, nil],
            ["users/update", other_user.id, nil]
          ]
        end
      end
    end

    context "with a user having no project access" do
      let(:user) { create(:user) }

      include_examples "consists of contract actions", with: "only global capabilities" do
        let(:expected) do
          [
            ["users/read", other_user.id, nil],
            ["users/update", other_user.id, nil]
          ]
        end
      end
    end
  end
end
