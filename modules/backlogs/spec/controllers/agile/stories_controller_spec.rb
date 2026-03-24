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

RSpec.describe Agile::StoriesController do
  context "with scrum_projects active", with_flag: { scrum_projects: true } do
    shared_let(:type) { create(:type) }
    let(:project) { create(:project) }
    let(:user) { create(:admin) }
    let(:sprint) { create(:agile_sprint, project:) }
    let(:target_sprint) { create(:agile_sprint, project:) }
    let(:work_package) { create(:work_package, project:, type:, sprint:) }
    let(:service_result) { ServiceResult.success(result: work_package) }
    let(:service) { instance_double(Stories::UpdateService, call: service_result) }

    current_user { user }

    before do
      allow(Stories::UpdateService)
        .to receive(:new)
        .with(user:, story: work_package)
        .and_return(service)

      allow(work_package).to receive(:sprint_id).and_return(sprint.id, target_sprint.id)
      allow(work_package).to receive(:sprint).and_return(target_sprint)
    end

    describe "PUT #move" do
      it "moves a generic sprint work package", :aggregate_failures do
        put :move, params: {
          project_id: project.id,
          sprint_id: sprint.id,
          id: work_package.id,
          target_id: "sprint:#{target_sprint.id}",
          position: 1
        }, format: :turbo_stream

        expect(response).to be_successful
        expect(response).to have_http_status(:ok)
        expect(service).to have_received(:call)
        expect(response).to have_turbo_stream(action: "replace", target: "backlogs-sprint-component-#{sprint.id}")
      end
    end
  end
end
