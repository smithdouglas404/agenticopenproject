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

RSpec.describe Story, ".backlogs (orphan task inclusion)" do
  let(:project) { create(:project) }
  let(:default_status) { create(:default_status) }
  let(:priority) { create(:priority) }
  let(:feature_type) { create(:type_feature) }
  let(:task_type) { create(:type_task) }
  let(:version) { create(:version, project:) }

  before do
    allow(Setting).to receive(:plugin_openproject_backlogs)
      .and_return({ "story_types" => [feature_type.id.to_s], "task_type" => task_type.id.to_s })
  end

  let!(:story_in_version) do
    create(:work_package, project:, type: feature_type, status: default_status, priority:, version:)
  end

  context "when a Task in this version has a parent story" do
    let(:parent_story) do
      create(:work_package, project:, type: feature_type, status: default_status, priority:, version:)
    end
    let!(:child_task) do
      create(:work_package, project:, type: task_type, status: default_status, priority:, version:,
                            parent: parent_story)
    end

    it "is not surfaced as a story in the backlog column" do
      result = described_class.backlogs(project.id, [version.id])
      expect(result[version.id].map(&:id)).not_to include(child_task.id)
    end
  end

  context "when a Task in this version has no parent" do
    let!(:orphan_task) do
      create(:work_package, project:, type: task_type, status: default_status, priority:, version:)
    end

    it "is surfaced alongside stories in the backlog column" do
      result = described_class.backlogs(project.id, [version.id])
      ids = result[version.id].map(&:id)
      expect(ids).to include(story_in_version.id, orphan_task.id)
    end
  end

  context "when a Task in this version has a non-story parent (e.g., another task)" do
    let(:parent_task) do
      create(:work_package, project:, type: task_type, status: default_status, priority:, version:)
    end
    let!(:nested_task) do
      create(:work_package, project:, type: task_type, status: default_status, priority:, version:,
                            parent: parent_task)
    end

    it "the nested task is excluded (it has a parent) but the parent task surfaces" do
      result = described_class.backlogs(project.id, [version.id])
      ids = result[version.id].map(&:id)
      expect(ids).to include(parent_task.id)
      expect(ids).not_to include(nested_task.id)
    end
  end

  context "when task_type is not configured" do
    before do
      allow(Setting).to receive(:plugin_openproject_backlogs)
        .and_return({ "story_types" => [feature_type.id.to_s], "task_type" => "" })
    end

    let!(:orphan_task) do
      create(:work_package, project:, type: task_type, status: default_status, priority:, version:)
    end

    it "does not surface tasks (the orphan-task clause is skipped to avoid NULL-id matches)" do
      result = described_class.backlogs(project.id, [version.id])
      expect(result[version.id].map(&:id)).not_to include(orphan_task.id)
    end
  end
end
