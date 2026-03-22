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

RSpec.describe Backlogs::SprintMenuComponent, type: :component do
  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:type_task) { create(:type_task) }

  let(:project) { create(:project, types: [type_feature, type_task]) }
  let(:sprint) { create(:agile_sprint, project:, name: "Sprint 1", start_date: Date.yesterday, finish_date: Date.tomorrow) }
  let(:user) { create(:user) }
  let(:permissions) { [] }
  let(:start_sprint_path) { Rails.application.routes.url_helpers.start_project_sprint_path(project, sprint) }
  let(:finish_sprint_path) { Rails.application.routes.url_helpers.finish_project_sprint_path(project, sprint) }

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return("story_types" => [type_feature.id.to_s], "task_type" => type_task.id.to_s)

    create(:member,
           project:,
           principal: user,
           roles: [create(:project_role, permissions:)])
    login_as(user)
  end

  def render_component
    render_inline(described_class.new(sprint:, project:, current_user: user))
  end

  def menu_items
    page.all(:role, :menuitem).map { it.text.squish }
  end

  describe "permission-based items" do
    context "with :manage_sprint_items permission" do
      let(:permissions) { %i[view_sprints manage_sprint_items] }

      it "shows Add new story item with compose icon" do
        render_component

        expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.new_story"))
        expect(page).to have_octicon(:compose)
      end
    end

    context "without :manage_sprint_items permission" do
      let(:permissions) { [:view_sprints] }

      it "does not show Add new story item" do
        render_component

        expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.new_story"))
      end
    end

    context "with :create_sprints permission" do
      let(:permissions) { %i[view_sprints create_sprints] }

      it "shows Edit item with pencil icon" do
        render_component

        expect(page).to have_css("action-menu")
        expect(page).to have_text(I18n.t("backlogs.backlog_menu_component.action_menu.edit_sprint"))
        expect(page).to have_octicon(:pencil)
      end
    end

    context "without :create_sprints permission" do
      let(:permissions) { [:view_sprints] }

      it "does not show Edit item" do
        render_component

        expect(page).to have_no_text(I18n.t("backlogs.backlog_menu_component.action_menu.edit_sprint"))
      end
    end
  end

  describe "task board actions" do
    let(:permissions) { %i[view_sprints view_work_packages] }

    context "when the sprint is active" do
      let(:sprint) do
        create(:agile_sprint,
               project:,
               name: "Sprint 1",
               start_date: Date.yesterday,
               finish_date: Date.tomorrow,
               status: "active")
      end
      let(:permissions) { %i[view_sprints view_work_packages start_complete_sprint] }
      let!(:task_board) { create(:board_grid_with_query, project:, linked: sprint) }

      it "shows Finish sprint first and Task board after Stories/Tasks" do
        render_component

        expect(menu_items.first).to eq("Finish sprint")
        expect(page).to have_octicon(:check)
        expect(page).to have_element(:form, action: finish_sprint_path, method: "post", "data-turbo": "false")
        expect(menu_items).to include("Stories/Tasks", "Task board")
        expect(menu_items.index("Task board")).to be > menu_items.index("Stories/Tasks")
      end
    end

    context "when the sprint is in planning and the user can start it" do
      let(:permissions) { %i[view_sprints view_work_packages start_complete_sprint] }

      it "shows Start sprint as the first item" do
        render_component

        expect(menu_items.first).to eq("Start sprint")
        expect(page).to have_octicon(:play)
        expect(page).to have_no_selector(:menuitem, text: "Task board")
        expect(page).to have_element(:form, action: start_sprint_path, method: "post", "data-turbo": "false")
      end

      context "when another sprint is already active" do
        let!(:active_sprint) do
          create(:agile_sprint,
                 project:,
                 name: "Sprint 2",
                 start_date: Date.yesterday,
                 finish_date: Date.tomorrow,
                 status: "active")
        end

        it "shows Start sprint disabled with a description" do
          render_component

          expect(menu_items.first).to include("Start sprint")
          expect(page).to have_selector(
            :menuitem,
            text: "Start sprint",
            disabled: true
          )
          expect(page).to have_text("Another sprint is already active.")
        end
      end

      context "when the sprint is in planning and the user cannot start it" do
        let(:permissions) { %i[view_sprints view_work_packages] }

        it "does not show task-board-related items" do
          render_component

          expect(page).to have_no_selector(:menuitem, text: "Start sprint")
          expect(page).to have_no_selector(:menuitem, text: "Task board")
        end
      end

      context "when the sprint is completed" do
        let(:sprint) do
          create(:agile_sprint,
                 project:,
                 name: "Sprint 1",
                 start_date: Date.yesterday,
                 finish_date: Date.tomorrow,
                 status: "completed")
        end
        let!(:task_board) { create(:board_grid_with_query, project:, linked: sprint) }

        it "shows Task board after Stories/Tasks" do
          render_component

          expect(menu_items).to include("Stories/Tasks", "Task board")
          expect(menu_items.index("Task board")).to be > menu_items.index("Stories/Tasks")
        end
      end
    end

    context "when the sprint is rendered in a receiving project" do
      let(:source_project) { create(:project, sprint_sharing: "share_all_projects", types: [type_feature, type_task]) }
      let(:project) { create(:project, sprint_sharing: "receive_shared", types: [type_feature, type_task]) }
      let(:sprint) do
        create(:agile_sprint,
               project: source_project,
               name: "Shared Sprint",
               start_date: Date.yesterday,
               finish_date: Date.tomorrow,
               status: "active")
      end
      let(:permissions) { %i[view_sprints view_work_packages create_sprints manage_sprint_items start_complete_sprint] }

      before do
        create(:member,
               project: source_project,
               principal: user,
               roles: [create(:project_role, permissions: %i[start_complete_sprint])])
      end

      it "hides Start sprint and Finish sprint" do
        render_component

        expect(page).to have_no_selector(:menuitem, text: "Start sprint")
        expect(page).to have_no_selector(:menuitem, text: "Finish sprint")
      end

      it "does not show Task board for a board in the source project" do
        create(:board_grid_with_query, project: source_project, linked: sprint)

        render_component

        expect(page).to have_no_selector(:menuitem, text: "Task board")
      end

      it "shows Task board for a board in the rendered project" do
        create(:board_grid_with_query, project:, linked: sprint)

        render_component

        expect(page).to have_selector(:menuitem, text: "Task board")
      end
    end
  end

  describe "always-visible items" do
    let(:permissions) { [:view_sprints] }

    it "renders stable ids on the action menu and stories/tasks item" do
      render_component

      expect(page).to have_element(:button, id: /\Aagile_sprint_#{sprint.id}_menu-button\z/)
      expect(page).to have_element(:ul, id: /\Aagile_sprint_#{sprint.id}_menu-list\z/)
      expect(page).to have_element(:a, id: /\Aagile_sprint_#{sprint.id}_menu_stories_tasks\z/)
    end

    it "shows Stories/Tasks link" do
      render_component

      expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.stories_tasks"))
    end
  end
end
