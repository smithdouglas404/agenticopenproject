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

RSpec.describe Grids::Widgets::ProjectStatusesController do
  shared_let(:user) { create(:admin) }
  current_user { user }

  let(:project) { build_stubbed(:project) }
  let(:service_result) { ServiceResult.failure }

  before do
    allow(Project)
      .to receive(:find)
            .with(project.identifier)
            .and_return(project)

    update_service = instance_double(Projects::UpdateService, call: service_result)

    allow(Projects::UpdateService)
      .to receive(:new)
            .with(user:, model: project)
            .and_return(update_service)
  end

  describe "GET #show" do
    before do
      get :show, params: { project_id: project }
    end

    it "renders show template", :aggregate_failures do
      expect(response).to be_successful
      expect(response).to render_template "show"
    end
  end

  describe "PUT #update" do
    before do
      put :update, params: { project_id: project, project: { **project_params } }, format: :turbo_stream
    end

    context "with valid status_explanation param" do
      let(:project_params) { { status_explanation: "Long explanation" } }

      context "when service call succeeds" do
        let(:service_result) { ServiceResult.success(result: project) }

        it "renders turbo streams updating Grids::Widgets::ProjectStatus and flash action", :aggregate_failures do
          expect(response).to be_successful
          expect(assigns(:project)).to eq project
          expect(response).to have_turbo_stream action: "update", target: "grids-widgets-project-status"
          expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        end
      end

      context "when service call fails" do
        let(:service_result) { ServiceResult.failure(result: project, message: "") }

        it "renders turbo stream flash action", :aggregate_failures do
          expect(response).not_to be_successful
          expect(response).to have_http_status :unprocessable_entity
          expect(assigns(:project)).to eq project
          expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        end
      end
    end

    context "with invalid params" do
      let(:project_params) { { not_status_code: "something" } }

      it "responds with 400 Bad Request status", :aggregate_failures do
        expect(response).not_to be_successful
        expect(response).to have_http_status :bad_request
      end
    end
  end
end
