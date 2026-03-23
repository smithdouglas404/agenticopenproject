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

require "rails_helper"

RSpec.describe Members::UserFilterComponent, type: :component do
  let(:admin) { create(:admin) }
  let(:project) { create(:project) }
  let(:role) { create(:project_role) }

  let(:group) { create(:group) }
  let(:direct_user) { create(:user) }
  let(:inherited_user) { create(:user) }

  let!(:group_member) { create(:member, project:, principal: group, roles: [role]) }
  let!(:direct_member) { create(:member, project:, principal: direct_user, roles: [role]) }
  let!(:inherited_member) do
    build(:member, project:, principal: inherited_user).tap do |member|
      member.member_roles.build(role:, inherited_from: group_member.member_roles.first.id)
      member.save!
    end
  end

  before do
    allow(User).to receive(:current).and_return(admin)
  end

  describe ".query" do
    subject(:query) { described_class.query(query_params) }

    let(:query_params) { { project_id: project.id.to_s } }

    it "hides inherited members by default" do
      expect(query).to be_a(Queries::Members::NonInheritedMemberQuery)
      expect(query.results).to include(group_member, direct_member)
      expect(query.results).not_to include(inherited_member)
    end

    context "when exclude_inherited is enabled explicitly" do
      let(:query_params) { { project_id: project.id.to_s, exclude_inherited: "1" } }

      it "hides inherited-only members" do
        expect(query).to be_a(Queries::Members::NonInheritedMemberQuery)
        expect(query.results).to include(group_member, direct_member)
        expect(query.results).not_to include(inherited_member)
      end
    end

    context "when exclude_inherited is disabled" do
      let(:query_params) { { project_id: project.id.to_s, exclude_inherited: "0" } }

      it "includes inherited-only members" do
        expect(query).to be_a(Queries::Members::MemberQuery)
        expect(query.results).to include(group_member, direct_member, inherited_member)
      end
    end
  end

  describe ".filter_param_keys" do
    it "includes exclude_inherited" do
      expect(described_class.filter_param_keys).to include(:exclude_inherited)
    end
  end
end
