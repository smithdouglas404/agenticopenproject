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
  let(:stories) { [] }
  let(:user) { create(:user) }
  let(:permissions) { [] }

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return("story_types" => [type_feature.id.to_s], "task_type" => type_task.id.to_s)

    # Set up user with specific permissions
    create(:member,
           project:,
           principal: user,
           roles: [create(:project_role, permissions:)])
    login_as(user)
  end

  def render_component
    render_inline(described_class.new(sprint:, project:, current_user: user))
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
