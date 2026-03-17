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
require_relative "../../support/pages/backlogs"

RSpec.describe "Start and finish sprints", :js, with_flag: { scrum_projects: true } do
  let(:project) { create(:project) }
  let(:permissions) do
    %i[view_sprints add_work_packages view_work_packages create_sprints manage_sprint_items
       start_complete_sprint show_board_views manage_board_views save_queries
       manage_public_queries]
  end
  let(:user) do
    create(:user, member_with_permissions: { project => permissions })
  end
  let(:backlogs_page) { Pages::Backlogs.new(project) }
  let(:story_type) { create(:type_feature) }
  let(:task_type) do
    type = create(:type_task)
    project.types << type

    type
  end
  let!(:first_sprint) do
    create(:agile_sprint,
           project:,
           start_date: Date.new(2025, 9, 5),
           finish_date: Date.new(2025, 9, 15))
  end
  let!(:second_sprint) do
    create(:agile_sprint,
           project:,
           start_date: Date.new(2025, 9, 16),
           finish_date: Date.new(2025, 9, 26))
  end
  let!(:closed_sprint) do
    create(:agile_sprint,
           project:,
           status: "completed",
           start_date: Date.new(2025, 8, 25),
           finish_date: Date.new(2025, 9, 4))
  end

  # Necessary so that work packages can be created via dialog
  shared_let(:default_status) { create(:default_status) }
  shared_let(:default_priority) { create(:default_priority) }

  before do
    login_as(user)

    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return("story_types" => [story_type.id.to_s], "task_type" => task_type.id.to_s)

    create(:workflow, type: task_type, old_status: default_status, new_status: default_status, role: create(:project_role))

    backlogs_page.visit!
  end

  it "starts the sprint and redirects to the board" do
    backlogs_page.click_in_sprint_menu(first_sprint, "Start sprint")

    expect_and_dismiss_flash type: :success, message: "The sprint was started."

    expect(page).to have_current_path(%r{/projects/#{project.identifier}/boards/\d+})
    expect(first_sprint.reload.task_board).to be_present
    expect(first_sprint.reload).to be_active
  end

  context "when the sprint is active" do
    let!(:first_sprint) do
      create(:agile_sprint,
             project:,
             status: "active",
             start_date: Date.new(2025, 9, 5),
             finish_date: Date.new(2025, 9, 15))
    end
    let!(:task_board) { create(:board_grid_with_query, project:, linked: first_sprint) }

    it "finishes the sprint and returns to the backlog" do
      backlogs_page.within_sprint_menu(first_sprint) do |menu|
        expect(menu).to have_selector :menuitem, "Finish sprint"
        expect(menu).to have_css "form[action='#{finish_project_sprint_path(project, first_sprint)}'][data-turbo='false']"
        menu.find(:button, "Finish sprint").click
      end

      backlogs_page.expect_current_path
      expect_and_dismiss_flash type: :success, message: "The sprint was completed."
      expect(first_sprint.reload).to be_completed
      backlogs_page.expect_sprint_names_in_order(second_sprint.name)
    end
  end
end
