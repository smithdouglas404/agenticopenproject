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
require "services/base_services/behaves_like_update_service"

RSpec.describe CustomFields::LinkWithRoleService, type: :model do
  it_behaves_like "BaseServices update service" do
    let(:model_instance) { build_stubbed(:project_custom_field, :user) }
  end

  describe "#modify_exiting_memberships" do
    shared_let(:user) { create(:admin) }

    let(:project1) { create(:project) }
    let(:project2) { create(:project) }

    let(:project_role1) { create(:project_role) }
    let(:project_role2) { create(:project_role) }

    let(:custom_field) { create(:user_project_custom_field, multi_value: true, projects: [project1, project2]) }
    let(:contract_class) { CustomFields::UpdateContract }
    let(:contract_instance) { instance_double(contract_class, validate: true) }

    let(:instance) { described_class.new(user:, model: custom_field, contract_class:) }

    subject { instance.call(attributes) }

    before do
      User.current = user
      allow(contract_class).to receive(:new).with(custom_field, user, options: {}).and_return(contract_instance)
    end

    context "when the field was not associated with a role before" do
      context "when assigning a role" do
        let(:attributes) { { role_id: project_role2.id } }
      end
    end

    context "when the field was associated with a role before" do
      let(:custom_field) do
        create(:user_project_custom_field, multi_value: true, projects: [project1, project2], role: project_role1)
      end

      context "when changing the role" do
        let(:attributes) { { role_id: project_role2.id } }
      end

      context "when removing the role" do
        let(:attributes) { { role_id: nil } }
      end
    end
  end
end
