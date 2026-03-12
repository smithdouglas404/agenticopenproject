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

RSpec.describe RbWikisController do
  let(:project) do
    create(:project, enabled_module_names: %w[work_package_tracking backlogs wiki])
  end
  let(:sprint) { create(:sprint, project:) }
  let(:current_user) { create(:user) }

  before do
    allow(Setting).to receive(:plugin_openproject_backlogs)
      .and_return({ "story_types" => ["1"], "task_type" => "2" })

    create(:member,
           user: current_user,
           roles: [create(:project_role, permissions: %i[view_work_packages view_versions create_sprints])],
           project:)
    login_as current_user
  end

  describe "#edit" do
    context "when the project wiki is missing" do
      before do
        project.wiki.destroy!
      end

      it "re-creates the wiki and redirects to wiki edit" do
        expect(project.reload.wiki).to be_nil

        get :edit, params: { project_id: project.id, sprint_id: sprint.id }

        expect(project.reload.wiki).to be_present
        expect(response).to redirect_to(
          controller: "/wiki",
          action: "edit",
          project_id: project.id,
          id: sprint.reload.wiki_page_title
        )
      end
    end

    context "when wiki module is disabled" do
      let(:project) do
        create(:project, enabled_module_names: %w[work_package_tracking backlogs])
      end

      it "returns not found instead of raising route generation errors" do
        get :edit, params: { project_id: project.id, sprint_id: sprint.id }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
