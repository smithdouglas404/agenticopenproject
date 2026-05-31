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

RSpec.describe Versions::ReleaseNotes do
  let(:type) { create(:type, name: "Feature", position: 1) }
  let(:project) { create(:project, types: [type]) }
  let(:release) { create(:version, project:, name: "Release 1.0", kind: "release") }
  let(:release_cf) { create(:multi_version_wp_custom_field, version_kind: "release") }
  let(:closed_status) { create(:closed_status) }
  let(:open_status) { create(:status) }

  let!(:done_wp) { create(:work_package, project:, type:, status: closed_status, subject: "Shipped feature") }
  let!(:open_wp) { create(:work_package, project:, type:, status: open_status, subject: "Still in progress") }

  subject(:notes) { described_class.new(release) }

  before do
    project.work_package_custom_fields << release_cf
    type.custom_fields << release_cf
    RequestStore.clear!
    [done_wp, open_wp].each do |wp|
      wp.custom_field_values = { release_cf.id => [release.id.to_s] }
      wp.save!
    end
  end

  describe "#grouped_work_packages" do
    it "includes only completed work packages of the release, grouped by type" do
      expect(notes.grouped_work_packages).to eq(type => [done_wp])
    end
  end

  describe "#to_markdown" do
    subject(:markdown) { notes.to_markdown }

    it "renders the release name, the type heading and the done work package" do
      expect(markdown).to include("# Release 1.0")
      expect(markdown).to include("## Feature")
      expect(markdown).to include("- ##{done_wp.id} Shipped feature")
    end

    it "excludes work packages that are not done" do
      expect(markdown).not_to include("Still in progress")
    end
  end

  describe "#any?" do
    it { expect(notes).to be_any }

    context "without completed work packages" do
      before { done_wp.update!(status: open_status) }

      it { expect(notes).not_to be_any }
    end
  end
end
