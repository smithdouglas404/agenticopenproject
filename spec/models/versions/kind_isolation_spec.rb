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

# Verifies that the native version_id (Sprint) selection set and Release-typed
# version custom fields stay separate, scoped by Version#kind.
RSpec.describe "Version kind isolation" do # rubocop:disable RSpec/DescribeClass
  shared_let(:project) { create(:project) }
  shared_let(:sprint) { create(:version, project:, name: "Sprint A", kind: "sprint") }
  shared_let(:release) { create(:version, project:, name: "Release 1.0", kind: "release") }

  describe "Project#assignable_versions" do
    it "returns versions of all kinds when no kind is given" do
      expect(project.assignable_versions).to contain_exactly(sprint, release)
    end

    it "restricts to sprints when kind: 'sprint'" do
      expect(project.assignable_versions(kind: "sprint")).to contain_exactly(sprint)
    end

    it "restricts to releases when kind: 'release'" do
      expect(project.assignable_versions(kind: "release")).to contain_exactly(release)
    end
  end

  describe "a Release version custom field (version_kind: 'release')" do
    let(:custom_field) do
      create(:version_wp_custom_field, version_kind: "release")
    end

    it "only offers release versions" do
      expect(custom_field.send(:possible_versions, project)).to contain_exactly(release)
    end
  end

  describe "the native version_id field on a work package" do
    let(:work_package) { build(:work_package, project:) }

    it "accepts a sprint version" do
      work_package.version = sprint
      contract = WorkPackages::CreateContract.new(work_package, build_stubbed(:admin))
      contract.validate

      expect(contract.errors[:version_id]).to be_empty
    end

    it "rejects a release version" do
      work_package.version = release
      contract = WorkPackages::CreateContract.new(work_package, build_stubbed(:admin))
      contract.validate

      expect(contract.errors.symbols_for(:version_id)).to include(:inclusion)
    end
  end
end
