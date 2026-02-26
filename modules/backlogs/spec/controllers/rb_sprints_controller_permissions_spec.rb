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

RSpec.describe RbSprintsController, "permissions" do
  let(:sprint_project) do
    create(:project, enabled_module_names: %w[work_package_tracking backlogs])
  end
  let(:sprint) { create(:sprint, project: sprint_project) }

  let(:other_project) do
    create(:project, enabled_module_names: %w[work_package_tracking backlogs]).tap do |p|
      create(:member,
             user: current_user,
             roles: [create(:project_role, permissions: [:update_sprints])],
             project: p)
    end
  end

  let(:current_user) { create(:user) }

  before do
    allow(Setting).to receive(:plugin_openproject_backlogs)
      .and_return({ "story_types" => ["1"], "task_type" => "2" })
    login_as current_user
  end

  describe "#update" do
    let(:original_name) { sprint.name }
    let(:new_name) { "a better name!" }

    context "when the user has access to a different project but not the sprint's project" do
      it "does not allow updating the sprint via a foreign project_id" do
        original_name # memoize before request

        patch :update,
              params: {
                project_id: other_project.id,
                id: sprint.id,
                sprint: {
                  name: new_name
                }
              },
              format: :turbo_stream
        sprint.reload

        expect(response).to have_http_status(:not_found)
        expect(sprint.name).to eq(original_name)
      end
    end

    context "when the user has access to the sprint's own project" do
      before do
        create(:member,
               user: current_user,
               roles: [create(:project_role, permissions: %i[view_work_packages view_versions update_sprints])],
               project: sprint_project)
      end

      it "allows updating the sprint" do
        skip "Incorrect permissions for updating Sprint"

        patch :update,
              params: {
                project_id: sprint_project.id,
                id: sprint.id,
                sprint: {
                  name: new_name
                }
              },
              format: :turbo_stream
        sprint.reload

        expect(sprint.name).to eq(new_name)
      end
    end
  end
end
