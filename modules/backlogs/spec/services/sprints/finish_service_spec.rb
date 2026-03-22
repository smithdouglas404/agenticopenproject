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

require "rails_helper"

RSpec.describe Sprints::FinishService do
  shared_let(:project) { create(:project, enabled_module_names: %w[backlogs work_package_tracking]) }
  shared_let(:open_status) { create(:status, is_closed: false) }
  shared_let(:closed_status) { create(:status, is_closed: true) }
  shared_let(:type) { create(:type_feature) }
  shared_let(:priority) { create(:priority) }

  let(:user) do
    create(:user, member_with_permissions: {
             project => %i[view_work_packages view_sprints manage_sprint_items start_complete_sprint]
           })
  end
  let(:sprint) { create(:agile_sprint, project:, status: sprint_status) }
  let(:sprint_status) { "active" }
  let(:instance) { described_class.new(user:, model: sprint) }

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return({ "story_types" => [type.id.to_s], "task_type" => type.id.to_s })
  end

  subject(:result) { instance.call }

  context "when the sprint has no unfinished work packages" do
    it "completes the sprint", :aggregate_failures do
      expect(result).to be_success
      expect(sprint.reload).to be_completed
    end
  end

  context "when the sprint has a closed work package" do
    let!(:closed_wp) do
      create(:work_package, project:, sprint:, status: closed_status, type:, priority:)
    end

    it "completes the sprint ignoring the closed work package", :aggregate_failures do
      expect(result).to be_success
      expect(sprint.reload).to be_completed
      expect(closed_wp.reload.sprint).to eq(sprint)
    end
  end

  context "when the sprint has unfinished (open) work packages" do
    let!(:open_wp) do
      create(:work_package, project:, sprint:, status: open_status, type:, priority:)
    end

    context "without specifying a target sprint" do
      it "returns failure with unfinished_work_packages error and leaves the sprint active", :aggregate_failures do
        expect(result).not_to be_success
        expect(result.includes_error?(:base, :unfinished_work_packages)).to be true
        expect(sprint.reload).to be_active
        expect(open_wp.reload.sprint).to eq(sprint)
      end
    end

    context "when specifying a target sprint to move the work packages to" do
      let(:target_sprint) { create(:agile_sprint, project:, status: "in_planning") }

      subject(:result) { instance.call(move_to_sprint_id: target_sprint.id, send_notifications: false) }

      it "moves the open work packages and completes the sprint", :aggregate_failures do
        expect(result).to be_success
        expect(sprint.reload).to be_completed
        expect(open_wp.reload.sprint).to eq(target_sprint)
      end
    end

    context "when specifying a non-existent target sprint id" do
      subject(:result) { instance.call(move_to_sprint_id: 0, send_notifications: false) }

      # find_by returns nil for id: 0, so UpdateService is called with sprint: nil,
      # which unassigns the WPs from the sprint. The contract then sees no unfinished WPs.
      it "unassigns the open work packages and completes the sprint", :aggregate_failures do
        expect(result).to be_success
        expect(sprint.reload).to be_completed
        expect(open_wp.reload.sprint).to be_nil
      end
    end

    context "when specifying a target sprint not shared with the project" do
      let(:other_project) { create(:project, enabled_module_names: %w[backlogs work_package_tracking]) }
      let(:target_sprint) { create(:agile_sprint, project: other_project, status: "in_planning") }

      subject(:result) { instance.call(move_to_sprint_id: target_sprint.id, send_notifications: false) }

      it "returns failure on the work package update and leaves the sprint active", :aggregate_failures do
        expect(result).not_to be_success
        expect(sprint.reload).to be_active
        expect(open_wp.reload.sprint).to eq(sprint)
      end
    end
  end

  context "when the sprint has multiple unfinished work packages and a target sprint is given" do
    let(:target_sprint) { create(:agile_sprint, project:, status: "in_planning") }
    let!(:open_wp1) do
      create(:work_package, project:, sprint:, status: open_status, type:, priority:)
    end
    let!(:open_wp2) do
      create(:work_package, project:, sprint:, status: open_status, type:, priority:)
    end
    let!(:closed_wp) do
      create(:work_package, project:, sprint:, status: closed_status, type:, priority:)
    end

    subject(:result) { instance.call(move_to_sprint_id: target_sprint.id, send_notifications: false) }

    it "moves only open work packages and completes the sprint", :aggregate_failures do
      expect(result).to be_success
      expect(sprint.reload).to be_completed
      expect(open_wp1.reload.sprint).to eq(target_sprint)
      expect(open_wp2.reload.sprint).to eq(target_sprint)
      expect(closed_wp.reload.sprint).to eq(sprint)
    end
  end

  context "when the sprint is not active" do
    let(:sprint_status) { "in_planning" }

    it "returns failure and leaves the sprint unchanged", :aggregate_failures do
      expect(result).not_to be_success
      expect(result.errors[:status]).to be_present
      expect(sprint.reload).to be_in_planning
    end
  end

  context "when the sprint is already completed" do
    let(:sprint_status) { "completed" }

    it "returns failure and leaves the sprint unchanged", :aggregate_failures do
      expect(result).not_to be_success
      expect(result.errors[:status]).to be_present
      expect(sprint.reload).to be_completed
    end
  end

  context "when the user lacks start_complete_sprint permission" do
    let(:user) do
      create(:user, member_with_permissions: {
               project => %i[view_work_packages view_sprints]
             })
    end

    it "returns an unauthorized error and leaves the sprint active", :aggregate_failures do
      expect(result).not_to be_success
      expect(result.includes_error?(:base, :error_unauthorized)).to be true
      expect(sprint.reload).to be_active
    end
  end
end
