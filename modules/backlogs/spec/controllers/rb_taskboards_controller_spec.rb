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

RSpec.describe RbTaskboardsController do
  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:type_task) { create(:type_task) }
  let(:user) { create(:user) }
  let(:permissions) { [] }
  let(:project) { create(:project, member_with_permissions: { user => permissions }) }
  let(:status) { create(:status, name: "status 1", is_default: true) }
  let(:board) { create(:board_grid_with_query, project:) }

  current_user { user }

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return({ "story_types" => [type_feature.id], "task_type" => type_task.id })
  end

  describe "GET show" do
    context "with the feature flag inactive", with_flag: { scrum_projects: false } do
      let(:sprint) { create(:sprint, project:) }
      let(:permissions) { %i[view_sprints view_work_packages] }

      before do
        get :show, params: { project_id: project.identifier, sprint_id: sprint.id }
      end

      it "renders the show template" do
        expect(response).to be_successful
        expect(response).to render_template :show
      end

      context "as a member with view_sprints permission" do
        let(:permissions) { %i[view_sprints view_work_packages] }

        it "grants access" do
          expect(response).to be_successful
          expect(response).to render_template :show
        end
      end

      context "as a member without view_sprints permission" do
        let(:permissions) { [:view_project] }

        it "denies access" do
          expect(response).to have_http_status(:not_found)
        end
      end

      context "as a non-member" do
        let(:permissions) { [] }

        current_user { create(:user) }

        it "denies access" do
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
