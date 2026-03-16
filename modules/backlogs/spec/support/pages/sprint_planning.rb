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

require "support/pages/page"

module Pages
  class SprintPlanning < Page
    attr_reader :project

    def initialize(project)
      super()
      @project = project
    end

    def alter_attributes_in_details_view(story, **attributes)
      within_details_view(story) do |details_view|
        attributes.each do |key, value|
          details_view
            .edit_field(key.to_s.camelize(:lower))
            .update(value) # rubocop:disable Rails/SaveBang

          details_view.expect_and_dismiss_toaster message: "Successful update."
        end
      end
    end

    def edit_story_in_details_view(story, **attributes)
      click_in_story_menu(story, "Open details view")

      alter_attributes_in_details_view(story, **attributes)
    end

    def click_in_sprint_menu(sprint, item_name)
      within_sprint_menu(sprint) do |menu|
        menu.find(:menuitem, text: item_name).click
      end
    end

    def click_in_story_menu(story, item_name)
      within_story_menu(story) do |menu|
        menu.find(:menuitem, text: item_name).click
      end
    end

    def drag_in_sprint(moved, target, before: true)
      moved_element = find(story_selector(moved))
      target_element = find(story_selector(target))

      drag_n_drop_element from: moved_element, to: target_element, offset_x: 0, offset_y: before ? -5 : +10
    end

    def sprint_names_in_order
      page.find_all("#sprint_backlogs_container > section .CollapsibleHeader-title").map(&:text)
    end

    def expect_sprint_names_in_order(*sprint_names)
      expect(sprint_names_in_order).to eq(sprint_names)
    end

    def expect_story_in_sprint(story, sprint)
      within_sprint(sprint) do
        expect(page)
          .to have_selector(work_package_selector(story).to_s)
      end
    end

    def expect_story_not_in_sprint(story, sprint)
      within_sprint(sprint) do
        expect(page)
          .to have_no_selector(work_package_selector(story).to_s)
      end
    end

    def expect_velocity(backlog, velocity)
      within("#backlog_#{backlog.id} .velocity") do
        expect(page)
          .to have_content(velocity.to_s)
      end
    end

    def expect_and_dismiss_error(message)
      expect(page).to have_content message

      click_on "Cancel"
    end

    def path
      sprint_planning_backlogs_project_backlogs_path(project)
    end

    def within_story_menu(story, &)
      within_story(story) do
        button = find(:button, accessible_name: "Story actions")
        button.click

        within_menu_controlled_by(button, &)
      end
    end

    def within_details_view(story, &)
      details_view = expect_details_view(story)

      yield details_view
    end

    def expect_details_view(story)
      details_view = Pages::PrimerizedSplitWorkPackage.new(story)
      details_view.expect_tab :overview
      details_view.expect_subject

      expect(page).to have_current_path details_backlogs_project_backlogs_path(story.project, story)
      wait_for_network_idle

      details_view
    end

    def open_create_sprint_dialog
      find_test_selector("op-sprints--new-sprint-button", text: "Sprint").click
    end

    def expect_sprint_dialog
      expect(page).to have_css("#new-sprint-dialog")
    end

    def expect_create_work_package_dialog
      expect(page).to have_css("#create-work-package-dialog")
    end

    def within_sprint_menu(backlog, &)
      within_sprint(backlog) do
        find(:button, accessible_name: "Sprint actions").click

        within(:menu, &)
      end
    end

    private

    def within_story(story, &)
      within(story_selector(story), &)
    end

    def within_sprint(sprint, &)
      within(sprint_selector(sprint), &)
    end

    def sprint_selector(sprint)
      "#agile_sprint_#{sprint.id}"
    end

    def backlog_selector(backlog)
      "#backlog_#{backlog.id}"
    end

    def story_selector(story)
      "#story_#{story.id}"
    end

    def work_package_selector(story)
      "#work_package_#{story.id}"
    end

    def within_menu_controlled_by(button)
      menu_id = button[:controls] || button["aria-controls"]

      within(:menu, id: menu_id) do
        yield page
      end
    end
  end
end
