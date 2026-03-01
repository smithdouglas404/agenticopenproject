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

RSpec.describe TaskBoards::CreateService do
  let(:user) { create(:user) }
  let(:project) { create(:project) }
  let(:type_task) { create(:type_task) }
  let(:status1) { create(:status) }
  let(:status2) { create(:status) }
  let(:instance) { described_class.new(user:) }

  before do
    create(:workflow, type: type_task, old_status: status1, new_status: status2, role: create(:project_role))

    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return({ "task_type" => type_task.id.to_s })
  end

  describe ".ensure" do
    subject(:result) { described_class.ensure(user:, project:, name: "Test Board") }

    context "when a board with the given name already exists" do
      let!(:existing_board) { create(:board_grid_with_query, project:, name: "Test Board") }

      it { is_expected.to be_success }

      it "returns the existing board" do
        expect(result.result).to eq(existing_board)
      end

      it "does not create a new board" do
        expect { result }.not_to change(Boards::Grid, :count)
      end
    end

    context "when no board exists" do
      it { is_expected.to be_success }

      it "creates and returns a new board" do
        expect { result }.to change(Boards::Grid, :count).by(1)
        expect(result.result).to be_a(Boards::Grid)
      end
    end

    context "when a race condition occurs (RecordNotUnique)" do
      let!(:existing_board) { create(:board_grid_with_query, project:, name: "Test Board") }
      let(:service_double) { instance_double(described_class) }

      before do
        allow(Boards::Grid).to receive_messages(find_by: nil, find_by!: existing_board)
        allow(described_class).to receive(:new).and_return(service_double)
        allow(service_double).to receive(:call).and_raise(ActiveRecord::RecordNotUnique)
      end

      it { is_expected.to be_success }

      it "returns the board created by the concurrent request" do
        expect(result.result).to eq(existing_board)
      end
    end
  end

  describe "#call" do
    subject(:result) { instance.call(project:, name: "Test Board") }

    context "when successful" do
      it { is_expected.to be_success }

      it "returns a Boards::Grid as result" do
        expect(result.result).to be_a(Boards::Grid)
        expect(result.result).to be_persisted
      end

      it "creates one Query per status" do
        expect { result }.to change(Query, :count).by(2)
      end

      it "creates one widget per status" do
        expect(result.result.widgets.size).to eq(2)
      end

      it "sets the correct grid options" do
        expect(result.result.options).to include(
          "type" => "action",
          "attribute" => "status"
        )
      end
    end

    context "when grid creation fails" do
      before do
        allow(Boards::Grid).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it { is_expected.to be_failure }

      it "rolls back query creation" do
        expect { result }.not_to change(Query, :count)
      end
    end
  end
end
