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

RSpec.describe Backlog, ".inbox_backlog" do
  let(:project) { create(:project) }
  let(:other_project) { create(:project) }
  let(:status) { create(:status) }
  let(:feature_type) { create(:type_feature) }
  let(:bug_type) { create(:type_bug) }
  let(:task_type) { create(:type_task) }
  let(:version) { create(:version, project:) }
  let(:agile_sprint) { create(:agile_sprint, project:) }

  before do
    allow(Setting).to receive(:plugin_openproject_backlogs)
      .and_return({ "story_types" => [feature_type.id.to_s], "task_type" => task_type.id.to_s })
  end

  subject { described_class.inbox_backlog(project) }

  it "is marked as the inbox and is neither a sprint nor an owner backlog" do
    expect(subject).to be_inbox
    expect(subject).not_to be_sprint_backlog
    expect(subject).not_to be_owner_backlog
  end

  it "has a sentinel to_key" do
    expect(subject.to_key).to eq(["inbox"])
  end

  context "when work packages have neither version nor sprint" do
    let!(:included) do
      create(:work_package, project:, type: feature_type, status:, version: nil, sprint: nil)
    end

    it "includes them" do
      expect(subject.stories.map(&:id)).to include(included.id)
    end
  end

  context "when work packages are assigned to a version" do
    let!(:in_version) do
      create(:work_package, project:, type: feature_type, status:, version:, sprint: nil)
    end

    it "excludes them" do
      expect(subject.stories.map(&:id)).not_to include(in_version.id)
    end
  end

  context "when work packages are assigned to an Agile sprint" do
    let!(:in_sprint) do
      create(:work_package, project:, type: feature_type, status:, version: nil, sprint: agile_sprint)
    end

    it "excludes them" do
      expect(subject.stories.map(&:id)).not_to include(in_sprint.id)
    end
  end

  context "when work packages exist in another project" do
    let!(:other) do
      create(:work_package, project: other_project, type: feature_type, status:, version: nil, sprint: nil)
    end

    it "is scoped to the requested project" do
      expect(subject.stories).to be_empty
    end
  end

  context "when unassigned work packages are of types outside story_types and task_type" do
    let!(:bug) do
      create(:work_package, project:, type: bug_type, status:, version: nil, sprint: nil)
    end

    it "excludes them so the Inbox mirrors the backlogs columns" do
      expect(subject.stories.map(&:id)).not_to include(bug.id)
    end
  end

  context "when unassigned work packages are of the configured task_type" do
    let!(:task) do
      create(:work_package, project:, type: task_type, status:, version: nil, sprint: nil)
    end

    it "includes them" do
      expect(subject.stories.map(&:id)).to include(task.id)
    end
  end

  context "when neither story_types nor task_type is configured" do
    before do
      allow(Setting).to receive(:plugin_openproject_backlogs)
        .and_return({ "story_types" => [], "task_type" => "0" })
    end

    let!(:unassigned) do
      create(:work_package, project:, type: feature_type, status:, version: nil, sprint: nil)
    end

    it "is empty" do
      expect(subject.stories).to be_empty
    end
  end

  context "when unassigned work packages are positioned" do
    let!(:third) do
      create(:work_package, project:, type: feature_type, status:, version: nil, sprint: nil, position: 30)
    end
    let!(:first) do
      create(:work_package, project:, type: feature_type, status:, version: nil, sprint: nil, position: 10)
    end
    let!(:second) do
      create(:work_package, project:, type: feature_type, status:, version: nil, sprint: nil, position: 20)
    end

    it "returns stories ordered by position with NULLS-LAST ranking" do
      expect(subject.stories.map(&:id)).to eq([first.id, second.id, third.id])
      expect(subject.stories.map(&:rank)).to eq([1, 2, 3])
    end
  end

  describe "closed status filter" do
    let(:closed_status) { create(:status, is_closed: true) }
    let!(:open_wp) do
      create(:work_package, project:, type: feature_type, status:, version: nil, sprint: nil)
    end
    let!(:closed_wp) do
      create(:work_package, project:, type: feature_type, status: closed_status, version: nil, sprint: nil)
    end

    it "excludes work packages in a closed status by default" do
      result = described_class.inbox_backlog(project)
      expect(result.stories.map(&:id)).to include(open_wp.id)
      expect(result.stories.map(&:id)).not_to include(closed_wp.id)
    end

    it "includes closed work packages when include_closed: true" do
      result = described_class.inbox_backlog(project, include_closed: true)
      expect(result.stories.map(&:id)).to include(open_wp.id, closed_wp.id)
    end
  end
end
