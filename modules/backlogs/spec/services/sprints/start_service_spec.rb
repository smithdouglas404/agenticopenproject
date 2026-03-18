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

RSpec.describe Sprints::StartService do
  shared_let(:project) { create(:project) }
  shared_let(:type_task) { create(:type_task) }
  shared_let(:status1) { create(:status) }
  shared_let(:status2) { create(:status) }
  let(:status) { "in_planning" }
  let(:sprint) { create(:agile_sprint, project:, status:) }
  let(:user) { create(:admin) }
  let(:instance) { described_class.new(user:, model: sprint) }

  subject(:result) { instance.call }

  before do
    create(:workflow, type: type_task, old_status: status1, new_status: status2, role: create(:project_role))

    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return({ "task_type" => type_task.id.to_s })
  end

  context "when no task board exists yet" do
    it "creates the board and starts the sprint", :aggregate_failures do
      expect(result).to be_success
      expect(sprint.reload).to be_active
      expect(sprint.task_board).to be_present
    end
  end

  context "when a task board already exists" do
    let!(:existing_board) { create(:board_grid_with_query, project:, linked: sprint) }

    it "starts the sprint without creating another board", :aggregate_failures do
      expect { result }.not_to change(Boards::Grid, :count)
      expect(result).to be_success
      expect(sprint.reload).to be_active
      expect(sprint.task_board).to eq(existing_board)
    end
  end

  context "when board creation fails" do
    let(:service_result) { ServiceResult.failure(message: "something went wrong") }
    let(:service) { instance_double(Boards::SprintTaskBoardCreateService, call: service_result) }

    before do
      allow(Boards::SprintTaskBoardCreateService)
        .to receive(:new)
        .with(user:)
        .and_return(service)
    end

    it "returns failure and leaves the sprint in planning", :aggregate_failures do
      expect(result).not_to be_success
      expect(result.message).to eq("something went wrong")
      expect(sprint.reload).to be_in_planning
      expect(sprint.task_board).to be_nil
    end
  end

  context "when sprint activation fails after board creation" do
    let!(:active_sprint) { create(:agile_sprint, project:, status: "active") }

    it "rolls back the created board", :aggregate_failures do
      expect(result).not_to be_success
      expect(sprint.reload).to be_in_planning
      expect(sprint.task_board).to be_nil
      expect(result.message).to eq(sprint.errors.full_messages.to_sentence)
    end
  end

  context "when the database unique constraint rejects sprint activation" do
    before do
      allow(sprint)
        .to receive(:active!)
        .and_raise(ActiveRecord::RecordNotUnique)
    end

    it "returns failure with the active sprint error", :aggregate_failures do
      expect(result).not_to be_success
      expect(result.errors[:status]).to include("only one active sprint is allowed per project.")
      expect(result.message).to eq(sprint.errors.full_messages.to_sentence)
      expect(sprint.reload).to be_in_planning
      expect(sprint.task_board).to be_nil
    end
  end

  context "when the sprint is already active" do
    let(:status) { "active" }

    it "returns failure and leaves the sprint unchanged", :aggregate_failures do
      expect(result).not_to be_success
      expect(result.message).to be_blank
      expect(sprint.reload).to be_active
      expect(sprint.task_board).to be_nil
    end
  end

  context "when the sprint is already completed" do
    let(:status) { "completed" }

    it "returns failure and leaves the sprint unchanged", :aggregate_failures do
      expect(result).not_to be_success
      expect(result.message).to be_blank
      expect(sprint.reload).to be_completed
      expect(sprint.task_board).to be_nil
    end
  end
end
