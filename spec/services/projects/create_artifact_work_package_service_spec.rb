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

RSpec.describe Projects::CreateArtifactWorkPackageService do
  shared_let(:status_new) { create(:status, name: "New") }
  shared_let(:type) { create(:type, name: "Project initiation") }
  shared_let(:user_custom_field) { create(:user_project_custom_field, name: "Project Manager") }
  shared_let(:assignee_user) { create(:user, firstname: "assignee_user") }
  shared_let(:current_user) { create(:user, lastname: "current_user") }
  shared_let(:role) { create(:project_role, permissions: %i[view_project_attributes add_work_packages]) }
  shared_let(:default_priority) { create(:default_priority) }
  shared_let(:project) do
    create(
      :project,
      types: [type],
      project_custom_fields: [user_custom_field],
      # project initiation request settings
      project_creation_wizard_enabled: true,
      project_creation_wizard_work_package_type_id: type.id,
      project_creation_wizard_status_when_submitted_id: status_new.id,
      project_creation_wizard_assignee_custom_field_id: user_custom_field.id,
      user_custom_field.attribute_name => assignee_user.id
    ).tap do |p|
      p.members << create(:member, principal: assignee_user, project: p, roles: [role])
      p.members << create(:member, principal: current_user, project: p, roles: [role])
    end
  end

  let(:mocked_contract) { instance_double(Projects::CreateArtifactWorkPackageContract, "mocked_contract") }
  let(:instance) do
    described_class.new(user: current_user, model: project).tap do |instance|
      allow(instance).to receive(:instantiate_contract).and_return(mocked_contract)
    end
  end

  before do
    login_as current_user
  end

  context "when contract is valid" do
    before do
      allow(mocked_contract).to receive(:validate).and_return(true)
    end

    it "creates an artifact work package (for after submitting a project initiation request)" do
      result = instance.call

      expect(result.errors.full_messages).to be_empty
      project = result.result
      expect(project.project_creation_wizard_artifact_work_package_id).to be_present
    end
  end
end
