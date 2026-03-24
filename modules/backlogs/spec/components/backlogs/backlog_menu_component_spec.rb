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

RSpec.describe Backlogs::BacklogMenuComponent, type: :component do
  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:type_task) { create(:type_task) }

  let(:project) { create(:project, types: [type_feature, type_task]) }
  let(:sprint) { create(:sprint, project:, name: "Sprint 1", start_date: Date.yesterday, effective_date: Date.tomorrow) }
  let(:stories) { [] }
  let(:backlog) { Backlog.new(sprint:, stories:, owner_backlog:) }
  let(:owner_backlog) { true }
  let(:user) { create(:user) }
  let(:permissions) { [] }

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return("story_types" => [type_feature.id.to_s], "task_type" => type_task.id.to_s)

    mock_permissions_for user do |mock|
      mock.allow_in_project(*permissions, project:)
    end
  end

  def render_component
    render_inline(described_class.new(backlog:, project:, current_user: user))
  end

  it "renders a stable id on the action menu and stories/tasks item" do
    render_component

    expect(page).to have_element(:button, id: /\Abacklog_#{sprint.id}_menu-button\z/)
    expect(page).to have_element(:ul, id: /\Abacklog_#{sprint.id}_menu-list\z/)
    expect(page).to have_element(:a, id: /\Asprint_#{sprint.id}_menu_stories_tasks\z/)
  end

  context "for a product owner backlog" do
    let(:owner_backlog) { true }

    describe "permission-based items" do
      context "with :add_work_packages and :assign_versions permission" do
        let(:permissions) { %i[view_sprints add_work_packages assign_versions] }

        it "shows Add new story item with compose icon" do
          render_component

          expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.new_story"))
          expect(page).to have_octicon(:compose)
        end
      end

      context "with :add_work_packages but without :assign_versions permission" do
        let(:permissions) { %i[view_sprints add_work_packages] }

        it "does not show Add new story item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.new_story"))
        end
      end

      context "with :assign_versions but without :add_work_packages permission" do
        let(:permissions) { %i[view_sprints assign_versions] }

        it "does not show Add new story item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.new_story"))
        end
      end

      context "without :assign_versions but with :add_work_packages and :manage_sprint_items permission" do
        let(:permissions) { %i[view_sprints add_work_packages manage_sprint_items] }

        it "does not show Add new story item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.new_story"))
        end
      end

      context "with :create_sprints permission" do
        let(:permissions) { %i[view_sprints create_sprints] }

        it "shows Properties item with gear icon" do
          render_component

          expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.properties"))
          expect(page).to have_octicon(:gear)
        end

        it "shows Edit item with pencil icon" do
          render_component

          expect(page).to have_css("action-menu")
          expect(page).to have_text(I18n.t("backlogs.backlog_menu_component.action_menu.edit_sprint"))
          expect(page).to have_octicon(:pencil)
        end
      end

      context "without :create_sprints permission" do
        let(:permissions) { [:view_sprints] }

        it "does not show Properties item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.properties"))
        end

        it "does not show Edit item" do
          render_component

          expect(page).to have_no_text(I18n.t("backlogs.backlog_menu_component.action_menu.edit_sprint"))
        end
      end

      context "with :view_sprints permission" do
        let(:permissions) { %i[view_sprints] }

        it "does not show Task board item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.task_board"))
        end
      end
    end

    describe "permission independent items" do
      let(:permissions) { [:view_sprints] }

      it "shows Stories/Tasks link" do
        render_component

        expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.stories_tasks"))
      end

      it "shows no Burndown chart link" do
        render_component

        expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.burndown_chart"))
      end
    end

    describe "module-based items" do
      context "when wiki module is enabled" do
        let(:permissions) { [:view_sprints] }
        let(:project) { create(:project, types: [type_feature, type_task], enabled_module_names: %w[backlogs wiki]) }

        it "does not show a Wiki item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.wiki"))
        end
      end
    end
  end

  context "for a sprint backlog" do
    let(:owner_backlog) { false }

    describe "permission-based items" do
      context "with :add_work_packages and :assign_versions permission" do
        let(:permissions) { %i[view_sprints add_work_packages assign_versions] }

        it "shows Add new story item with compose icon" do
          render_component

          expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.new_story"))
          expect(page).to have_octicon(:compose)
        end
      end

      context "with :add_work_packages but without :assign_versions permission" do
        let(:permissions) { %i[view_sprints add_work_packages] }

        it "does not show Add new story item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.new_story"))
        end
      end

      context "with :assign_versions but without :add_work_packages permission" do
        let(:permissions) { %i[view_sprints assign_versions] }

        it "does not show Add new story item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.new_story"))
        end
      end

      context "without :assign_versions but with :add_work_packages and :manage_sprint_items permission" do
        let(:permissions) { %i[view_sprints add_work_packages manage_sprint_items] }

        it "does not show Add new story item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.new_story"))
        end
      end

      context "with :create_sprints permission" do
        let(:permissions) { %i[view_sprints create_sprints] }

        it "shows Properties item with gear icon" do
          render_component

          expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.properties"))
          expect(page).to have_octicon(:gear)
        end

        it "shows Edit item with pencil icon" do
          render_component

          expect(page).to have_css("action-menu")
          expect(page).to have_text(I18n.t("backlogs.backlog_menu_component.action_menu.edit_sprint"))
          expect(page).to have_octicon(:pencil)
        end
      end

      context "without :create_sprints permission" do
        let(:permissions) { [:view_sprints] }

        it "does not show Properties item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.properties"))
        end

        it "does not show Edit item" do
          render_component

          expect(page).to have_no_text(I18n.t("backlogs.backlog_menu_component.action_menu.edit_sprint"))
        end
      end

      context "with :view_sprints permission" do
        let(:permissions) { %i[view_sprints] }

        it "shows Task board item" do
          render_component

          expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.task_board"))
        end
      end
    end

    describe "permission independent items" do
      let(:permissions) { [:view_sprints] }

      it "shows Stories/Tasks link" do
        render_component

        expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.stories_tasks"))
      end

      it "shows Burndown chart link" do
        render_component

        expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.burndown_chart"))
      end

      context "when sprint has no burndown (no dates)" do
        let(:sprint) { create(:sprint, project:, name: "Sprint 1", start_date: nil, effective_date: nil) }

        it "shows Burndown chart link as disabled" do
          render_component

          burndown_item = page.find("li", text: I18n.t(:"backlogs.backlog_menu_component.action_menu.burndown_chart"))
          expect(burndown_item[:class]).to include("ActionListItem--disabled")
        end
      end

      context "when sprint has burndown" do
        it "shows Burndown chart link as enabled" do
          render_component

          burndown_item = page.find("li", text: I18n.t(:"backlogs.backlog_menu_component.action_menu.burndown_chart"))
          expect(burndown_item[:class]).not_to include("ActionListItem--disabled")
        end
      end
    end

    describe "module-based items" do
      context "when wiki module is enabled" do
        let(:permissions) { [:view_sprints] }
        let(:project) { create(:project, types: [type_feature, type_task], enabled_module_names: %w[backlogs wiki]) }

        it "shows Wiki item" do
          render_component

          expect(page).to have_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.wiki"))
          expect(page).to have_octicon(:book)
        end
      end

      context "when wiki module is disabled" do
        let(:permissions) { [:view_sprints] }
        let(:project) { create(:project, types: [type_feature, type_task], enabled_module_names: %w[backlogs]) }

        it "does not show Wiki item" do
          render_component

          expect(page).to have_no_text(I18n.t(:"backlogs.backlog_menu_component.action_menu.wiki"))
        end
      end
    end
  end
end
