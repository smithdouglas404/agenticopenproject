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

RSpec.describe WorkPackageTargetVersion do
  let(:project) { create(:project) }
  let(:version) { create(:version, project:) }
  let(:work_package) { create(:work_package, project:) }
  let!(:join_row) { described_class.create!(work_package:, version:) }

  it { is_expected.to belong_to(:work_package) }
  it { is_expected.to belong_to(:version) }

  describe "cascades" do
    context "when deleting the work package" do
      it "removes the join row" do
        wp_id = work_package.id
        work_package.destroy!

        expect(described_class.where(work_package_id: wp_id)).not_to exist
      end
    end

    context "when deleting the version" do
      it "removes the join row" do
        version_id = version.id
        version.destroy!

        expect(described_class.where(version_id:)).not_to exist
      end
    end
  end

  describe "Version#target_work_packages" do
    it "returns work packages linked via the join table" do
      expect(version.target_work_packages).to include(work_package)
    end
  end

  describe "WorkPackage#target_versions" do
    it "returns versions linked via the join table" do
      expect(work_package.target_versions).to include(version)
    end
  end
end
