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

RSpec.describe Story, ".backlog_for" do
  let(:project) { create(:project) }
  let(:status) { create(:status) }
  let(:feature_type) { create(:type_feature) }
  let(:version) { create(:version, project:) }

  before do
    allow(Setting).to receive(:plugin_openproject_backlogs)
      .and_return({ "story_types" => [feature_type.id.to_s], "task_type" => "0" })
  end

  context "when the column has fewer stories than the limit" do
    let!(:s1) do
      create(:work_package, project:, type: feature_type, status:, version:, position: 1)
    end
    let!(:s2) do
      create(:work_package, project:, type: feature_type, status:, version:, position: 2)
    end

    it "returns the stories with truncated=false" do
      stories, truncated = described_class.backlog_for(project.id, version.id, limit: 5)

      expect(stories.map(&:id)).to eq([s1.id, s2.id])
      expect(truncated).to be(false)
    end

    it "assigns sequential ranks starting at 1" do
      stories, _ = described_class.backlog_for(project.id, version.id, limit: 5)

      expect(stories.map(&:rank)).to eq([1, 2])
    end
  end

  context "when the column has exactly the limit" do
    let!(:s1) do
      create(:work_package, project:, type: feature_type, status:, version:, position: 1)
    end
    let!(:s2) do
      create(:work_package, project:, type: feature_type, status:, version:, position: 2)
    end

    it "returns all stories with truncated=false" do
      stories, truncated = described_class.backlog_for(project.id, version.id, limit: 2)

      expect(stories.size).to eq(2)
      expect(truncated).to be(false)
    end
  end

  context "when the column has more stories than the limit" do
    let!(:stories_in_version) do
      Array.new(5) do |i|
        create(:work_package, project:, type: feature_type, status:, version:, position: i + 1)
      end
    end

    it "returns truncated=true and caps the result at the limit" do
      stories, truncated = described_class.backlog_for(project.id, version.id, limit: 3)

      expect(stories.size).to eq(3)
      expect(truncated).to be(true)
    end

    it "returns the first `limit` items in Story::ORDER (position asc)" do
      stories, _ = described_class.backlog_for(project.id, version.id, limit: 3)

      expect(stories.map(&:id)).to eq(stories_in_version.first(3).map(&:id))
    end

    it "preloads :status and :type so they don't N+1 during render" do
      stories, _ = described_class.backlog_for(project.id, version.id, limit: 3)

      # Asserting on `association(:status).loaded?` is the canonical way to
      # verify preload happened — accessing `.status` after the fact would
      # trigger lazy loading and mask a regression.
      expect(stories.first.association(:status).loaded?).to be(true)
      expect(stories.first.association(:type).loaded?).to be(true)
    end
  end

  context "when no stories exist in the requested version" do
    it "returns an empty array with truncated=false" do
      stories, truncated = described_class.backlog_for(project.id, version.id, limit: 3)

      expect(stories).to be_empty
      expect(truncated).to be(false)
    end
  end
end
