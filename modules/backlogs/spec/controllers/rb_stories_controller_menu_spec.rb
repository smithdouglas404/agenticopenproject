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

RSpec.describe RbStoriesController, "GET #menu (deferred menu items)" do
  render_views

  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:type_task) { create(:type_task) }
  shared_let(:user) { create(:admin) }
  current_user { user }

  let(:project) { create(:project) }
  let(:status) { create(:status, name: "status 1", is_default: true) }
  let(:sprint) { create(:sprint, project:) }

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return({ "story_types" => [type_feature.id], "task_type" => type_task.id })
  end

  describe "with a middle story (not first, not last)" do
    let!(:earlier) { create(:story, status:, version: sprint, project:, position: 1) }
    let!(:story)   { create(:story, status:, version: sprint, project:, position: 2) }
    let!(:later)   { create(:story, status:, version: sprint, project:, position: 3) }

    it "responds with success" do
      get :menu, params: { project_id: project.id, sprint_id: sprint.id, id: story.id }

      expect(response).to be_successful
    end

    it "renders the navigation items (Open details, Open fullscreen)" do
      get :menu, params: { project_id: project.id, sprint_id: sprint.id, id: story.id }

      expect(response.body).to include(I18n.t(:"js.button_open_details"))
      expect(response.body).to include(I18n.t(:"js.button_open_fullscreen"))
    end

    it "renders all four Move-to items" do
      get :menu, params: { project_id: project.id, sprint_id: sprint.id, id: story.id }

      expect(response.body).to include(I18n.t(:label_sort_highest))
      expect(response.body).to include(I18n.t(:label_sort_higher))
      expect(response.body).to include(I18n.t(:label_sort_lower))
      expect(response.body).to include(I18n.t(:label_sort_lowest))
    end
  end

  describe "with the first story in the column" do
    let!(:story) { create(:story, status:, version: sprint, project:, position: 1) }
    let!(:later) { create(:story, status:, version: sprint, project:, position: 2) }

    it "hides the Move-to-top and Move-up items" do
      get :menu, params: { project_id: project.id, sprint_id: sprint.id, id: story.id }

      expect(response.body).not_to include(I18n.t(:label_sort_highest))
      expect(response.body).not_to include(I18n.t(:label_sort_higher))
    end

    it "still renders Move-down and Move-to-bottom" do
      get :menu, params: { project_id: project.id, sprint_id: sprint.id, id: story.id }

      expect(response.body).to include(I18n.t(:label_sort_lower))
      expect(response.body).to include(I18n.t(:label_sort_lowest))
    end
  end

  describe "with the last story in the column" do
    let!(:earlier) { create(:story, status:, version: sprint, project:, position: 1) }
    let!(:story)   { create(:story, status:, version: sprint, project:, position: 2) }

    it "hides the Move-down and Move-to-bottom items" do
      get :menu, params: { project_id: project.id, sprint_id: sprint.id, id: story.id }

      expect(response.body).not_to include(I18n.t(:label_sort_lower))
      expect(response.body).not_to include(I18n.t(:label_sort_lowest))
    end

    it "still renders Move-to-top and Move-up" do
      get :menu, params: { project_id: project.id, sprint_id: sprint.id, id: story.id }

      expect(response.body).to include(I18n.t(:label_sort_highest))
      expect(response.body).to include(I18n.t(:label_sort_higher))
    end
  end

  describe "with the only story in the column" do
    let!(:story) { create(:story, status:, version: sprint, project:, position: 1) }

    it "hides all four Move-to items" do
      get :menu, params: { project_id: project.id, sprint_id: sprint.id, id: story.id }

      expect(response.body).not_to include(I18n.t(:label_sort_highest))
      expect(response.body).not_to include(I18n.t(:label_sort_higher))
      expect(response.body).not_to include(I18n.t(:label_sort_lower))
      expect(response.body).not_to include(I18n.t(:label_sort_lowest))
    end

    it "still renders the navigation items" do
      get :menu, params: { project_id: project.id, sprint_id: sprint.id, id: story.id }

      expect(response.body).to include(I18n.t(:"js.button_open_details"))
      expect(response.body).to include(I18n.t(:"js.button_open_fullscreen"))
    end
  end
end
