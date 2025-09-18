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

RSpec.describe Overviews::WidgetController do
  describe "project_status routing" do
    describe "GET #show" do
      it do
        expect(get("/projects/my-project/widgets/project_status"))
          .to route_to(
            controller: "overviews/widgets/project_statuses", action: "show", project_id: "my-project"
          )
      end
    end

    describe "PUT/PATCH #update" do
      it do
        expect(put("/projects/my-project/widgets/project_status"))
          .to route_to(
            controller: "overviews/widgets/project_statuses", action: "update", project_id: "my-project"
          )
      end

      it do
        expect(patch("/projects/my-project/widgets/project_status"))
          .to route_to(
            controller: "overviews/widgets/project_statuses", action: "update", project_id: "my-project"
          )
      end
    end
  end

  describe "project_status named routing" do
    describe "GET #show" do
      it do
        expect(get(project_widgets_project_status_path("my-project")))
          .to route_to(
            controller: "overviews/widgets/project_statuses", action: "show", project_id: "my-project"
          )
      end
    end

    describe "PUT/PATCH #update" do
      it do
        expect(put(project_widgets_project_status_path("my-project")))
          .to route_to(
            controller: "overviews/widgets/project_statuses", action: "update", project_id: "my-project"
          )
      end

      it do
        expect(patch(project_widgets_project_status_path("my-project")))
          .to route_to(
            controller: "overviews/widgets/project_statuses", action: "update", project_id: "my-project"
          )
      end
    end
  end
end
