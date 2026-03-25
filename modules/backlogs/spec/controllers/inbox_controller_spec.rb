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

RSpec.describe InboxController, with_flag: { scrum_projects_active: true } do
  current_user { user }

  let(:user) { create(:admin) }
  let(:project) { create(:project) }
  let!(:work_packages) { create_list(:work_package, 5, project:) }
  let(:work_package) { create(:work_package, project:) }
  let(:setup_service_result) do
    allow(Stories::UpdateService)
      .to receive(:new)
      .and_return(instance_double(Stories::UpdateService, call: service_result))
  end

  before do
    setup_service_result if defined?(service_result)
    subject
  end

  describe "POST #reorder" do
    subject do
      post :reorder,
           params: { project_id: project.id, id: work_package.id, direction: "highest" },
           format: :turbo_stream
    end

    context "when service call succeeds" do
      it "replaces the inbox component and responds with turbo streams", :aggregate_failures do
        expect(response).to be_successful
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-inbox-component-#{project.id}"
        expect(assigns(:project)).to eq(project)
        expect(assigns(:work_package)).to eq(work_package)
      end

      it "moves the work package to the first place" do
        expect { work_package.reload }
          .to change(work_package, :position).from(6).to(1)
        expect { work_packages.each(&:reload) }
          .to change { work_packages.map(&:position) }
          .from([1, 2, 3, 4, 5])
          .to([2, 3, 4, 5, 6])
      end
    end

    context "when service call fails" do
      let(:service_result) { ServiceResult.failure(message: "Something went wrong") }

      it "renders an error flash with 422", :aggregate_failures do
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        expect(response).not_to have_turbo_stream action: "replace",
                                                  target: "backlogs-inbox-component-#{project.id}"
      end
    end

    context "with a user lacking project permission" do
      let(:user) { create(:user) }

      it "responds with 404" do
        expect(response).to have_http_status :not_found
      end
    end
  end

  describe "PUT #move" do
    let(:agile_sprint) { create(:agile_sprint, name: "Sprint 1", project:) }
    let(:target_id) { "sprint:#{agile_sprint.id}" }
    let(:position) { 1 }

    subject do
      put :move,
          params: {
            project_id: project.id,
            id: work_package.id,
            target_id:,
            position:
          },
          format: :turbo_stream
    end

    context "when moving to an Agile::Sprint" do
      it "replaces both the inbox and target sprint components", :aggregate_failures do
        expect(response).to be_successful
        expect(response).to have_turbo_stream action: "replace",
                                              target: "backlogs-inbox-component-#{project.id}"
        expect(response).to have_turbo_stream action: "replace",
                                              target: "backlogs-sprint-component-#{agile_sprint.id}"
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
      end
    end

    context "when reordering within the Inbox" do
      let(:target_id) { "inbox" }
      let(:position) { 2 }

      it "replaces only the inbox component without a flash", :aggregate_failures do
        expect(response).to be_successful
        expect(response).to have_turbo_stream action: "replace",
                                              target: "backlogs-inbox-component-#{project.id}"
        expect(response).not_to have_turbo_stream action: "flash", target: "op-primer-flash-component"
      end

      it "moves the work package to position 2" do
        expect { work_package.reload }
          .to change(work_package, :position).from(6).to(2)
        expect { work_packages.each(&:reload) }
          .to change { work_packages.map(&:position) }
          .from([1, 2, 3, 4, 5])
          .to([1, 3, 4, 5, 6])
      end
    end

    context "when service call fails" do
      let(:service_result) { ServiceResult.failure(message: "Move failed") }

      it "renders an error flash with 422 and does not replace components", :aggregate_failures do
        expect(response).to have_http_status :unprocessable_entity
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        expect(response).not_to have_turbo_stream action: "replace",
                                                  target: "backlogs-inbox-component-#{project.id}"
      end
    end

    context "with a user lacking project permission" do
      let(:user) { create(:user) }

      it "responds with 404" do
        expect(response).to have_http_status :not_found
      end
    end
  end
end
