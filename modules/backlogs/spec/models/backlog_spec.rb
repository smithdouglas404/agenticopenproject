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
        it { expect(Backlog.owner_backlogs(@project)[0]).not_to be_truncated } # rubocop:disable RSpec/InstanceVariable, RSpec/DescribedClass
      end

      describe "WITH more work packages than the column limit" do
        let(:feature_type) { create(:type_feature) }
        let(:status) { create(:status) }
        let(:truncating_project) do
          create(:project).tap do |p|
            allow(Setting).to receive(:plugin_openproject_backlogs)
              .and_return({ "story_types" => [feature_type.id.to_s], "task_type" => "0" })
            version = create(:version, project: p)
            version.version_settings.create!(display: VersionSetting::DISPLAY_RIGHT, project: p)
            Array.new(3) do |i|
              create(:work_package, project: p, type: feature_type, status:, version:, position: i + 1)
            end
          end
        end

        before { stub_const("Story::COLUMN_LIMIT", 2) }

        it "marks the backlog as truncated" do
          expect(described_class.owner_backlogs(truncating_project)[0]).to be_truncated
        end

        it "caps the stories to COLUMN_LIMIT" do
          expect(described_class.owner_backlogs(truncating_project)[0].stories.size).to eq(2)
        end

        it "exposes column_limit to callers (used by the view)" do
          expect(described_class.owner_backlogs(truncating_project)[0].column_limit).to eq(2)
        end
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
