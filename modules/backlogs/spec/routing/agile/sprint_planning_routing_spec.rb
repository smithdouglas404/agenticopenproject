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

RSpec.describe Agile::SprintPlanningController do
  describe "routing" do
    context "with the feature flag active", with_flag: { scrum_projects: true } do
      it {
        expect(get("/projects/project_42/backlogs/sprint_planning")).to route_to(
          controller: "agile/sprint_planning",
          action: "show",
          project_id: "project_42"
        )
      }

      it {
        expect(get("/projects/project_42/backlogs/details/33")).to route_to(
          controller: "agile/sprint_planning",
          action: "details",
          project_id: "project_42",
          work_package_id: "33",
          tab: :overview,
          work_package_split_view: true
        )
      }
    end

    context "with the feature flag active (named routes)", with_flag: { scrum_projects: true } do
      it {
        expect(get(sprint_planning_backlogs_project_backlogs_path("project_42"))).to route_to(
          controller: "agile/sprint_planning",
          action: "show",
          project_id: "project_42"
        )
      }
    end

    context "with the feature flag inactive", with_flag: { scrum_projects: false } do
      it "does not route sprint_planning" do
        expect(get("/projects/project_42/backlogs/sprint_planning")).not_to be_routable
      end
    end
  end
end
