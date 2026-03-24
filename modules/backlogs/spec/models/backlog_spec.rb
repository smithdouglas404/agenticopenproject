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

RSpec.describe Backlog do
  let(:project) { build(:project) }

  before do
    @feature = create(:type_feature)
    allow(Setting).to receive(:plugin_openproject_backlogs).and_return({ "story_types" => [@feature.id.to_s],
                                                                         "task_type" => "0" })
    @status = create(:status)
  end

  describe "Class Methods" do
    describe ".inbox_for" do
      let(:project) { create(:project) }
      let(:open_status) { create(:status, is_closed: false) }
      let(:closed_status) { create(:status, is_closed: true) }
      let(:agile_sprint) { create(:agile_sprint, project:) }

      before { login_as create(:admin) }

      subject(:inbox) { described_class.inbox_for(project:) }

      it "returns work packages with no sprint assigned and open status" do
        inbox_wp = create(:work_package, project:, status: open_status)
        create(:work_package, project:, status: closed_status)
        create(:work_package, project:, status: open_status, sprint: agile_sprint)

        expect(inbox).to contain_exactly(inbox_wp)
      end

      it "excludes work packages from other projects" do
        create(:work_package, status: open_status)
        own_wp = create(:work_package, project:, status: open_status)

        expect(inbox).to contain_exactly(own_wp)
      end

      it "orders by position ascending, falling back to id for unpositioned items" do
        wp1 = create(:work_package, project:, status: open_status, position: 2)
        wp2 = create(:work_package, project:, status: open_status, position: 1)
        wp3 = create(:work_package, project:, status: open_status, position: nil)
        wp4 = create(:work_package, project:, status: open_status, position: nil)

        wp3.update_column(:position, nil)
        wp4.update_column(:position, nil)

        expect(inbox).to eq([wp2, wp1, wp3, wp4])
      end
    end

    describe "#owner_backlogs" do
      describe "WITH one open version defined in the project" do
        before do
          @project = project
          @work_packages = [create(:work_package, subject: "work_package1", project: @project, type: @feature,
                                                  status: @status)]
          @version = create(:version, project:, work_packages: @work_packages)
          @version_settings = @version.version_settings.create(display: VersionSetting::DISPLAY_RIGHT, project:)
        end

        it { expect(Backlog.owner_backlogs(@project)[0]).to be_owner_backlog }
      end
    end
  end

  describe "ActiveModel naming" do
    let(:sprint) { build_stubbed(:sprint) }

    subject(:instance) { described_class.new(sprint:, stories: []) }

    it "exposes an ActiveModel model_name" do
      expect(described_class).to respond_to(:model_name)
      expect(described_class.model_name).to respond_to(:param_key)
    end

    it "implements #to_key" do
      expect(instance).to respond_to(:to_key)
    end
  end
end
