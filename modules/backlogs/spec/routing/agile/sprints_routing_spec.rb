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

RSpec.describe Agile::SprintsController do
  describe "routing" do
    context "with the feature flag active", with_flag: { scrum_projects: true } do
      it {
        expect(post("/projects/project_42/sprints")).to route_to(
          controller: "agile/sprints",
          action: "create",
          project_id: "project_42"
        )
      }

      it {
        expect(put("/projects/project_42/sprints/21")).to route_to(
          controller: "agile/sprints",
          action: "update",
          project_id: "project_42",
          id: "21"
        )
      }

      it {
        expect(get("/projects/project_42/sprints/new_dialog")).to route_to(
          controller: "agile/sprints",
          action: "new_dialog",
          project_id: "project_42"
        )
      }

      it {
        expect(get("/projects/project_42/sprints/refresh_form")).to route_to(
          controller: "agile/sprints",
          action: "refresh_form",
          project_id: "project_42"
        )
      }

      it {
        expect(get("/projects/project_42/sprints/21/edit_dialog")).to route_to(
          controller: "agile/sprints",
          action: "edit_dialog",
          project_id: "project_42",
          id: "21"
        )
      }

      it {
        expect(post("/projects/project_42/sprints/21/start")).to route_to(
          controller: "agile/sprints",
          action: "start",
          project_id: "project_42",
          id: "21"
        )
      }

      it {
        expect(post("/projects/project_42/sprints/21/finish")).to route_to(
          controller: "agile/sprints",
          action: "finish",
          project_id: "project_42",
          id: "21"
        )
      }
    end

    context "with the feature flag active (named routes)", with_flag: { scrum_projects: true } do
      it { expect(post(project_sprints_path("project_42"))).to be_routable }
      it { expect(put(project_sprint_path("project_42", 21))).to be_routable }
      it { expect(get(new_dialog_project_sprints_path("project_42"))).to be_routable }
      it { expect(get(refresh_form_project_sprints_path("project_42"))).to be_routable }
      it { expect(get(edit_dialog_project_sprint_path("project_42", 21))).to be_routable }
      it { expect(post(start_project_sprint_path("project_42", 21))).to be_routable }
      it { expect(post(finish_project_sprint_path("project_42", 21))).to be_routable }
    end

    context "with the feature flag inactive", with_flag: { scrum_projects: false } do
      it { expect(post("/projects/project_42/sprints")).not_to be_routable }
      it { expect(get("/projects/project_42/sprints/new_dialog")).not_to be_routable }
      it { expect(get("/projects/project_42/sprints/refresh_form")).not_to be_routable }
      it { expect(get("/projects/project_42/sprints/21/edit_dialog")).not_to be_routable }
      it { expect(post("/projects/project_42/sprints/21/start")).not_to be_routable }
      it { expect(post("/projects/project_42/sprints/21/finish")).not_to be_routable }

      # PUT /sprints/:id routes to legacy controller when flag inactive
      it {
        expect(put("/projects/project_42/sprints/21")).to route_to(
          controller: "rb_sprints",
          action: "update",
          project_id: "project_42",
          id: "21"
        )
      }
    end
  end
end
