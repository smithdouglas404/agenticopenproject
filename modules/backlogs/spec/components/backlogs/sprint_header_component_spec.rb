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

  def render_component(folded: false, active_sprint_ids: nil)
    render_inline(described_class.new(sprint:, project:, folded:, current_user: user, active_sprint_ids:))
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

      it "hides the story count counter" do
        render_component

        expect(page).to have_css(".Counter", text: "0", visible: :hidden)
      end

      it "shows 0 points" do
        render_component

        expect(page).to have_text("0 points", normalize_ws: true)
      end
    end

    context "when sprint has no dates" do
      let(:sprint) { build_stubbed(:agile_sprint, project:, name: "Sprint 1", start_date: nil, finish_date: nil) }

      it "renders without date range or calendar icon" do
        render_component

        expect(page).to have_no_css("time")
        expect(page).to have_no_octicon(:calendar)
      end
    end
  end

  describe "start and finish actions" do
    context "when the sprint is in planning and the user can start it" do
      it "shows a Start button" do
        render_component

        expect(page).to have_selector(:link_or_button, "Start")
        expect(page).to have_octicon(:play)
      end

      it "does not show Finish" do
        render_component

        expect(page).to have_no_selector(:link_or_button, "Finish")
      end

      context "when another sprint is already active" do
        let!(:active_sprint) do
          create(:agile_sprint, project:, name: "Active Sprint", status: "active",
                                start_date: Date.yesterday, finish_date: Date.tomorrow)
        end

        it "shows Start disabled with a reason" do
          render_component(active_sprint_ids: [active_sprint.id])

          expect(page).to have_selector(:link_or_button, "Start", aria: { disabled: true })
          expect(page).to have_text("Another sprint is already active.")
        end
      end

      context "when the sprint has no start date" do
        let(:start_date) { nil }

        it "shows Start disabled with a missing dates reason" do
          render_component

          expect(page).to have_selector(:link_or_button, "Start", aria: { disabled: true })
          expect(page).to have_text("Start and finish dates are required in order to start the sprint.")
        end
      end

      context "when the sprint has no finish date" do
        let(:finish_date) { nil }

        it "shows Start disabled with a missing dates reason" do
          render_component

          expect(page).to have_selector(:link_or_button, "Start", aria: { disabled: true })
          expect(page).to have_text("Start and finish dates are required in order to start the sprint.")
        end
      end
    end

    context "when the sprint is active and the user can finish it" do
      let(:sprint) do
        create(:agile_sprint, project:, name: "Sprint 1", status: "active",
                              start_date:, finish_date:)
      end

      it "shows a Finish button" do
        render_component

        expect(page).to have_selector(:link_or_button, "Finish")
        expect(page).to have_octicon(:check)
      end

      it "does not show Start" do
        render_component

        expect(page).to have_no_selector(:link_or_button, "Start")
      end
    end

    context "when the sprint is completed" do
      let(:sprint) do
        create(:agile_sprint, project:, name: "Sprint 1", status: "completed",
                              start_date:, finish_date:)
      end

      it "shows neither Start nor Finish" do
        render_component

        expect(page).to have_no_selector(:link_or_button, "Start")
        expect(page).to have_no_selector(:link_or_button, "Finish")
      end
    end

    context "when the user lacks the start_complete_sprint permission" do
      let(:user) do
        create(:user, member_with_permissions: { project => %i[view_sprints view_work_packages] })
      end

      it "does not show Start" do
        render_component

        expect(page).to have_no_selector(:link_or_button, "Start")
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
