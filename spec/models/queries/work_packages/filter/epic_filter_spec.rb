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

RSpec.describe Queries::WorkPackages::Filter::EpicFilter do
  let(:project) { build_stubbed(:project) }
  let(:query) { build_stubbed(:query, project:) }

  it_behaves_like "basic query filter" do
    let(:class_key) { :epic }
    let(:type) { :list }

    before do
      instance.context = query
    end

    describe "#where" do
      subject(:where) { instance.where }

      before do
        instance.operator = "="
        instance.values = %w[1 2]
      end

      it "filters by epic_id" do
        expect(where).to include("work_packages.epic_id")
      end
    end
  end

  describe "cross-project epic visibility" do
    let(:admin) { create(:admin) }
    let(:epic_type) { create(:type, name: "Epic") }
    let(:task_type) { create(:type, name: "Task") }
    let(:epic_project) { create(:project, types: [epic_type, task_type]) }
    let(:other_project) { create(:project, types: [epic_type, task_type]) }
    let(:epic) { create(:work_package, project: epic_project, type: epic_type) }
    let!(:linked_task) do
      create(:work_package, project: other_project, type: task_type, epic_id: epic.id)
    end
    let(:other_query) { build(:query, project: other_project, user: admin) }
    let(:instance) do
      described_class.create!(name: :epic, context: other_query, operator: "=", values: [epic.id.to_s])
    end

    before { login_as(admin) }

    it "is valid when filtering by an epic that lives in a different project" do
      expect(instance).to be_valid
    end
  end
end
