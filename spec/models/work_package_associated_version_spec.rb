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

RSpec.describe WorkPackageAssociatedVersion do
  let(:project) { create(:project) }
  let(:version) { create(:version, project:) }
  let(:work_package) { create(:work_package, project:) }

  it { is_expected.to belong_to(:work_package) }
  it { is_expected.to belong_to(:version) }

  describe "validations" do
    it "is invalid with an unknown kind" do
      row = described_class.new(work_package:, version:, kind: "unknown")
      expect(row).not_to be_valid
      expect(row.errors[:kind]).to be_present
    end

    it "is valid with kind 'target'" do
      row = described_class.new(work_package:, version:, kind: "target")
      expect(row).to be_valid
    end

    it "is valid with kind 'observed_in'" do
      row = described_class.new(work_package:, version:, kind: "observed_in")
      expect(row).to be_valid
    end
  end

  describe "cascades" do
    context "when deleting the work package" do
      let!(:join_row) { described_class.create!(work_package:, version:, kind: "target") }

      it "removes the join row" do
        wp_id = work_package.id
        work_package.destroy!

        expect(described_class.where(work_package_id: wp_id)).not_to exist
      end
    end

    context "when deleting the version" do
      let!(:join_row) { described_class.create!(work_package:, version:, kind: "target") }

      it "removes the join row" do
        version_id = version.id
        version.destroy!

        expect(described_class.where(version_id:)).not_to exist
      end
    end
  end

  describe "Version#work_packages_target_versions" do
    let!(:join_row) { described_class.create!(work_package:, version:, kind: "target") }

    it "returns work packages linked via the join table with kind=target" do
      expect(version.work_packages_target_versions).to include(work_package)
    end
  end

  describe "Version#work_packages_observed_in_versions" do
    let!(:join_row) { described_class.create!(work_package:, version:, kind: "observed_in") }

    it "returns work packages linked via the join table with kind=observed_in" do
      expect(version.work_packages_observed_in_versions).to include(work_package)
    end
  end

  describe "WorkPackage#target_versions" do
    let!(:join_row) { described_class.create!(work_package:, version:, kind: "target") }

    it "returns versions linked with kind=target" do
      expect(work_package.target_versions).to include(version)
    end
  end

  describe "WorkPackage#observed_in_versions" do
    let!(:join_row) { described_class.create!(work_package:, version:, kind: "observed_in") }

    it "returns versions linked with kind=observed_in" do
      expect(work_package.observed_in_versions).to include(version)
    end
  end
end
