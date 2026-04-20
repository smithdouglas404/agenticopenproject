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

  before do
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

      it "shows Add new work package item with plus icon" do
        rendered_component = render_component

        expect(page).to have_text(I18n.t(:"backlogs.sprint_menu_component.action_menu.add_work_package"))
        expect(page).to have_octicon(:plus)
        expect(rendered_component.to_s).to include("sprint_id=#{sprint.id}")
      end
    end

    context "without :manage_sprint_items permission" do
      let(:permissions) { [:view_sprints] }

      it "does not show Add work package item" do
        render_component

        expect(page).to have_no_text(I18n.t(:"backlogs.sprint_menu_component.action_menu.add_work_package"))
      end
    end

    context "with :create_sprints permission" do
      let(:permissions) { %i[view_sprints create_sprints] }

      it "shows Edit item with pencil icon" do
        render_component

        expect(page).to have_css("action-menu")
        expect(page).to have_text(I18n.t("backlogs.sprint_menu_component.action_menu.edit_sprint"))
        expect(page).to have_octicon(:pencil)
      end
    end

    context "without :create_sprints permission" do
      let(:permissions) { [:view_sprints] }

      it "does not show Edit item" do
        render_component

        expect(page).to have_no_text(I18n.t("backlogs.sprint_menu_component.action_menu.edit_sprint"))
      end
    end
  end

  describe "task board link" do
    let(:permissions) { %i[view_sprints view_work_packages] }

    context "when the sprint is active and has a task board" do
      let(:sprint) do
        create(:agile_sprint,
               project:,
               name: "Sprint 1",
               start_date: Date.yesterday,
               finish_date: Date.tomorrow,
               status: "active")
      end
      let(:permissions) { %i[view_sprints view_work_packages create_sprints manage_sprint_items] }
      let!(:task_board) { create(:board_grid_with_query, project:, linked: sprint) }

      it "shows Sprint board" do
        render_component

        expect(menu_items).to include("Sprint board")
      end

      it "renders dividers between each menu section" do
        render_component

        expect(menu_items).to eq(["Edit sprint", "Add work package", "Sprint board", "Burndown chart"])
        expect(page).to have_list_item position: 2, role: "presentation"
        expect(page).to have_list_item position: 4, role: "presentation"
      end
    end

    context "when the sprint is completed and has a task board" do
      let(:sprint) do
        create(:agile_sprint,
               project:,
               name: "Sprint 1",
               start_date: Date.yesterday,
               finish_date: Date.tomorrow,
               status: "completed")
      end
      let!(:task_board) { create(:board_grid_with_query, project:, linked: sprint) }

      it "shows Sprint board" do
        render_component

        expect(menu_items).to include("Sprint board")
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
      let(:permissions) do
        %i[view_sprints view_work_packages show_board_views create_sprints manage_sprint_items start_complete_sprint]
      end

      before do
        create(:member,
               project: source_project,
               principal: user,
               roles: [create(:project_role, permissions: %i[view_sprints start_complete_sprint])])
      end

      it "does not show Sprint board for a board in the source project" do
        create(:board_grid_with_query, project: source_project, linked: sprint)

        render_component

        expect(page).to have_no_selector(:menuitem, text: "Sprint board")
      end

      it "shows Sprint board for a board in the rendered project" do
        create(:board_grid_with_query, project:, linked: sprint)

        render_component

        expect(page).to have_selector(:menuitem, text: "Sprint board")
      end
    end
  end
end
