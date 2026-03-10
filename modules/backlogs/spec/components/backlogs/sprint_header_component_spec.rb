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

RSpec.describe Backlogs::SprintHeaderComponent, type: :component do
  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:type_task) { create(:type_task) }
  shared_let(:default_status) { create(:default_status) }
  shared_let(:default_priority) { create(:default_priority) }
  shared_let(:user) { create(:admin) }
  current_user { user }

  let(:project) { create(:project, types: [type_feature, type_task]) }
  let(:start_date) { Date.new(2024, 1, 15) }
  let(:finish_date) { Date.new(2024, 1, 29) }
  let(:sprint) { create(:agile_sprint, project:, name: "Sprint 1", start_date:, finish_date:) }
  let(:state) { :show }
  let(:folded) { false }

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return("story_types" => [type_feature.id.to_s], "task_type" => type_task.id.to_s)
  end

  def render_component(folded: false)
    render_inline(described_class.new(sprint:, folded:, current_user: user))
  end

  describe "show state (default)" do
    context "with stories" do
      let!(:story1) do
        create(:story,
               project:,
               type: type_feature,
               status: default_status,
               priority: default_priority,
               story_points: 5,
               sprint:)
      end
      let!(:story2) do
        create(:story,
               project:,
               type: type_feature,
               status: default_status,
               priority: default_priority,
               story_points: 3,
               sprint:)
      end
      let!(:story_with_nil_points) do
        create(:story,
               project:,
               type: type_feature,
               status: default_status,
               priority: default_priority,
               story_points: nil,
               sprint:)
      end

      it "displays sprint name in h4" do
        render_component

        expect(page).to have_css("h3", text: "Sprint 1")
      end

      it "shows story count via Primer::Beta::Counter" do
        render_component

        expect(page).to have_css(".Counter", text: "3")
      end

      it "shows formatted date range with time tags" do
        render_component

        expect(page).to have_css("time[datetime='2024-01-15']")
        expect(page).to have_css("time[datetime='2024-01-29']")
      end

      it "shows story points total (nil treated as 0)" do
        render_component

        # 5 + 3 + 0 = 8 points
        expect(page).to have_text("8 points", normalize_ws: true)
      end

      it "renders collapse/expand chevrons" do
        render_component

        expect(page).to have_octicon(:"chevron-up", visible: :all)
        expect(page).to have_octicon(:"chevron-down", visible: :all)
      end

      it "renders BacklogMenuComponent" do
        render_component

        expect(page).to have_css("action-menu")
      end

      it "renders a stable id on the sprint menu trigger" do
        render_component

        expect(page).to have_element(:button, id: /\Aagile_sprint_#{sprint.id}_menu-button\z/)
      end
    end

    context "with no stories" do
      let(:stories) { [] }

      it "shows 0 story count" do
        render_component

        expect(page).to have_css(".Counter", text: "0")
      end

      it "shows 0 points" do
        render_component

        expect(page).to have_text("0 points", normalize_ws: true)
      end
    end

    context "when sprint has no dates" do
      let(:sprint) { build_stubbed(:agile_sprint, project:, name: "Sprint 1", start_date: nil, finish_date: nil) }

      it "renders without date range" do
        render_component

        expect(page).to have_no_css("time")
      end
    end
  end

  describe "folded state" do
    context "when folded is true" do
      it "renders chevron-up hidden and chevron-down visible" do
        render_component(folded: true)

        # When folded, chevron-up is hidden (has hidden attribute on svg)
        # and chevron-down is visible (for expanding)
        expect(page).to have_css("svg[hidden][data-target='collapsible-header.arrowUp']", visible: :hidden)
        expect(page).to have_css("svg[data-target='collapsible-header.arrowDown']:not([hidden])", visible: :all)
      end
    end

    context "when folded is false" do
      it "renders chevron-down hidden and chevron-up visible" do
        render_component(folded: false)

        # When expanded, chevron-down is hidden (has hidden attribute)
        # and chevron-up is visible (for collapsing)
        expect(page).to have_css("svg[hidden][data-target='collapsible-header.arrowDown']", visible: :hidden)
        expect(page).to have_css("svg[data-target='collapsible-header.arrowUp']:not([hidden])", visible: :all)
      end
    end
  end
end
