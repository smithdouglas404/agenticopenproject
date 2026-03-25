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
require_relative "../support/pages/sprint_planning"

RSpec.describe "Inbox column in sprint planning view", :js, with_flag: { scrum_projects: true } do
  let!(:project) do
    create(:project,
           types: [type],
           enabled_module_names: %w[work_package_tracking backlogs])
  end
  let!(:type) { create(:type) }
  let!(:sprint) { create(:agile_sprint, name: "Sprint 1", project:) }
  let!(:role) do
    create(:project_role,
           permissions: %i[
             view_project
             view_sprints
             manage_sprint_items
             add_work_packages
             view_work_packages
             edit_work_packages
           ])
  end
  let!(:current_user) { create(:user, member_with_roles: { project => role }) }

  let(:planning_page) { Pages::SprintPlanning.new(project) }

  before do
    login_as current_user
  end

  context "when the inbox has no work packages" do
    before { planning_page.visit! }

    it "shows the blankslate" do
      planning_page.expect_inbox_blankslate
    end
  end

  context "with work packages in the inbox" do
    let!(:inbox_wp1) { create(:work_package, project:) }
    let!(:inbox_wp2) { create(:work_package, project:) }
    let!(:inbox_wp3) { create(:work_package, project:) }

    before { planning_page.visit! }

    it "displays all items in position order and hides the blankslate" do
      planning_page.expect_inbox_item(inbox_wp1)
      planning_page.expect_inbox_item(inbox_wp2)
      planning_page.expect_inbox_item(inbox_wp3)
      planning_page.expect_inbox_items_in_order(inbox_wp1, inbox_wp2, inbox_wp3)
      planning_page.expect_no_inbox_blankslate
    end

    it "allows reordering items via the kebab menu", :aggregate_failures do
      # First item has no upward actions
      planning_page.within_inbox_menu(inbox_wp1) do |menu|
        planning_page.within_move_submenu(menu) do |submenu|
          expect(submenu).to have_no_selector(:menuitem, text: "Move to top")
          expect(submenu).to have_no_selector(:menuitem, text: "Move up")
          expect(submenu).to have_selector(:menuitem, text: "Move down")
          expect(submenu).to have_selector(:menuitem, text: "Move to bottom")
        end
      end

      # Last item has no downward actions
      planning_page.within_inbox_menu(inbox_wp3) do |menu|
        planning_page.within_move_submenu(menu) do |submenu|
          expect(submenu).to have_selector(:menuitem, text: "Move to top")
          expect(submenu).to have_selector(:menuitem, text: "Move up")
          expect(submenu).to have_no_selector(:menuitem, text: "Move down")
          expect(submenu).to have_no_selector(:menuitem, text: "Move to bottom")
        end
      end

      planning_page.click_in_inbox_move_menu(inbox_wp1, "Move down")
      planning_page.expect_inbox_items_in_order(inbox_wp2, inbox_wp1, inbox_wp3)

      planning_page.click_in_inbox_move_menu(inbox_wp1, "Move down")
      planning_page.expect_inbox_items_in_order(inbox_wp2, inbox_wp3, inbox_wp1)

      planning_page.click_in_inbox_move_menu(inbox_wp2, "Move to bottom")
      planning_page.expect_inbox_items_in_order(inbox_wp3, inbox_wp1, inbox_wp2)

      planning_page.click_in_inbox_move_menu(inbox_wp2, "Move to top")
      planning_page.expect_inbox_items_in_order(inbox_wp2, inbox_wp3, inbox_wp1)

      planning_page.click_in_inbox_move_menu(inbox_wp1, "Move up")
      planning_page.expect_inbox_items_in_order(inbox_wp2, inbox_wp1, inbox_wp3)
    end

    describe "moving backlog items to a sprint via the 'Move to sprint' menu item" do
      let!(:sprint2) { create(:agile_sprint, name: "Sprint 2", project:) }
      let!(:sprint_wp) { create(:work_package, project:, sprint:) }

      before { planning_page.visit! }

      it "moves the item to the bottom of the selected sprint" do
        planning_page.click_in_inbox_move_menu(inbox_wp1, "Move to sprint")

        within("#move-to-sprint-dialog") do
          # Expect to have all sprints listed
          expect(page).to have_select("target_id", with_options: ["Sprint 1", "Sprint 2"])

          select sprint.name, from: "target_id"
          click_button "Save"
        end

        planning_page.expect_no_inbox_item(inbox_wp1)
        expect_and_dismiss_flash(message: "Successful move from Inbox to Sprint 1.")
        planning_page.expect_story_in_sprint(inbox_wp1, sprint)
        planning_page.expect_work_packages_in_sprint_in_order(sprint, work_packages: [sprint_wp, inbox_wp1])
      end
    end

    describe "moving backlog items to a sprint via drag-and-drop" do
      it "moves multiple items into the sprint one by one" do
        planning_page.drag_inbox_item_to_sprint(inbox_wp1, sprint)
        planning_page.expect_no_inbox_item(inbox_wp1)
        expect_and_dismiss_flash(message: "Successful move from Inbox to Sprint 1.")

        planning_page.drag_inbox_item_to_sprint(inbox_wp2, sprint)
        planning_page.expect_no_inbox_item(inbox_wp2)
        expect_and_dismiss_flash(message: "Successful move from Inbox to Sprint 1.")

        planning_page.drag_inbox_item_to_sprint(inbox_wp3, sprint)
        planning_page.expect_no_inbox_item(inbox_wp3)
        expect_and_dismiss_flash(message: "Successful move from Inbox to Sprint 1.")

        planning_page.expect_inbox_blankslate
        planning_page.expect_story_in_sprint(inbox_wp1, sprint)
        planning_page.expect_story_in_sprint(inbox_wp2, sprint)
        planning_page.expect_story_in_sprint(inbox_wp3, sprint)
      end
    end

    describe "reordering sprint items via the kebab menu" do
      let!(:sprint_wp1) { create(:work_package, project:, sprint:) }
      let!(:sprint_wp2) { create(:work_package, project:, sprint:) }
      let!(:sprint_wp3) { create(:work_package, project:, sprint:) }

      before { planning_page.visit! }

      it "allows reordering items", :aggregate_failures do
        items_in_visual_order = planning_page.sprint_items_in_visual_order(sprint, sprint_wp1, sprint_wp2, sprint_wp3)
        top_item = items_in_visual_order[0]
        middle_item = items_in_visual_order[1]
        bottom_item = items_in_visual_order[2]

        # First item has no upward actions
        planning_page.within_sprint_story_menu(top_item) do |menu|
          planning_page.within_move_submenu(menu) do |submenu|
            expect(submenu).to have_no_selector(:menuitem, text: "Move to top")
            expect(submenu).to have_no_selector(:menuitem, text: "Move up")
            expect(submenu).to have_selector(:menuitem, text: "Move down")
            expect(submenu).to have_selector(:menuitem, text: "Move to bottom")
          end
        end

        # Last item has no downward actions
        planning_page.within_sprint_story_menu(bottom_item) do |menu|
          planning_page.within_move_submenu(menu) do |submenu|
            expect(submenu).to have_selector(:menuitem, text: "Move to top")
            expect(submenu).to have_selector(:menuitem, text: "Move up")
            expect(submenu).to have_no_selector(:menuitem, text: "Move down")
            expect(submenu).to have_no_selector(:menuitem, text: "Move to bottom")
          end
        end

        planning_page.click_in_sprint_story_move_menu(top_item, "Move down")
        planning_page.expect_work_packages_in_sprint_in_order(sprint, work_packages: [middle_item, top_item, bottom_item])

        planning_page.click_in_sprint_story_move_menu(top_item, "Move down")
        planning_page.expect_work_packages_in_sprint_in_order(sprint, work_packages: [middle_item, bottom_item, top_item])

        planning_page.click_in_sprint_story_move_menu(middle_item, "Move to bottom")
        planning_page.expect_work_packages_in_sprint_in_order(sprint, work_packages: [bottom_item, top_item, middle_item])

        planning_page.click_in_sprint_story_move_menu(middle_item, "Move to top")
        planning_page.expect_work_packages_in_sprint_in_order(sprint, work_packages: [middle_item, bottom_item, top_item])

        planning_page.click_in_sprint_story_move_menu(top_item, "Move up")
        planning_page.expect_work_packages_in_sprint_in_order(sprint, work_packages: [middle_item, top_item, bottom_item])
      end
    end

    describe "moving sprint items back to the inbox via drag-and-drop" do
      let!(:sprint_wp1) { create(:work_package, project:, sprint:) }
      let!(:sprint_wp2) { create(:work_package, project:, sprint:) }

      before { planning_page.visit! }

      it "moves all sprint items back to the inbox" do
        planning_page.drag_sprint_item_to_inbox(sprint_wp1)
        expect_and_dismiss_flash(message: "Successful move from Sprint 1 to Inbox.")

        planning_page.drag_sprint_item_to_inbox(sprint_wp2)
        expect_and_dismiss_flash(message: "Successful move from Sprint 1 to Inbox.")

        planning_page.expect_story_not_in_sprint(sprint_wp1, sprint)
        planning_page.expect_story_not_in_sprint(sprint_wp2, sprint)
        planning_page.expect_inbox_item(sprint_wp1)
        planning_page.expect_inbox_item(sprint_wp2)
      end
    end
  end
end
