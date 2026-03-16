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

RSpec.describe "RbMasterBacklogs", :skip_csrf, type: :rails_request do
  include Turbo::TestAssertions

  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:type_task) { create(:type_task) }
  shared_let(:user) { create(:admin) }
  shared_let(:project) { create(:project) }
  shared_let(:status)  { create(:status, name: "status 1", is_default: true) }
  shared_let(:sprint)  { create(:sprint, project:) }
  shared_let(:story) { create(:story, status:, version: sprint, project:) }

  current_user { user }

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return({ "story_types" => [type_feature.id], "task_type" => type_task.id })
  end

  describe "GET #index" do
    it "is successful" do
      get "/projects/#{project.identifier}/backlogs"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)

      expect(response).to have_turbo_frame "backlogs_container", src: "/projects/#{project.identifier}/backlogs"
      expect(response).to have_turbo_frame "content-bodyRight"
    end

    context "with a Turbo Frame request" do
      it "renders the list partial" do
        get "/projects/#{project.identifier}/backlogs", headers: { "Turbo-Frame" => "backlogs_container" }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template("rb_master_backlogs/_list")

        expect(response).to have_turbo_frame "backlogs_container"
        expect(response).to have_no_turbo_frame "content-bodyRight"
      end
    end

    context "with the scrum project feature flag active", with_flag: { scrum_projects: true } do
      it "redirects to sprint_planning" do
        get "/projects/#{project.identifier}/backlogs"

        expect(response).to redirect_to("/projects/#{project.identifier}/backlogs/sprint_planning")
      end
    end
  end

  describe "GET #details" do
    it "is successful" do
      get "/projects/#{project.identifier}/backlogs/details/#{story.id}"

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)

      expect(response).to have_turbo_frame "backlogs_container", src: "/projects/#{project.identifier}/backlogs"
      expect(response).to have_turbo_frame "content-bodyRight"
    end

    context "with the scrum project feature flag active", with_flag: { scrum_projects: true } do
      it "is successful and renders sprint_planning" do
        get "/projects/#{project.identifier}/backlogs/details/#{story.id}"

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:sprint_planning)
      end
    end

    context "with a Turbo Frame request" do
      it "renders the split view" do
        get "/projects/#{project.identifier}/backlogs/details/#{story.id}",
            headers: { "Turbo-Frame" => "content-bodyRight" }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template("work_packages/split_view")

        expect(response).to have_turbo_frame "content-bodyRight"
        expect(response).to have_no_turbo_frame "backlogs_container"
      end
    end
  end
end
