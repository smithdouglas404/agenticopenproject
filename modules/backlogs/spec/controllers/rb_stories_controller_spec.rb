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

RSpec.describe RbStoriesController do
  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:type_task) { create(:type_task) }

  current_user { user }

  let(:user) { create(:admin) }
  let(:project) { create(:project) }
  let(:status) { create(:status, name: "status 1", is_default: true) }
  let(:version_sprint) { create(:sprint, project:) }
  let(:story) { create(:story, status:, version: version_sprint, project:) }

  # Via this setting, version_sprint is used as backlog:
  let!(:version_setting) { create(:version_setting, version: version_sprint, project:, display: VersionSetting::DISPLAY_RIGHT) }

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
            .and_return({ "story_types" => [type_feature.id], "task_type" => type_task.id })
  end

  describe "PUT #move_legacy" do
    context "with a user lacking project permission" do
      let(:user) { create(:user) }

      it "responds with 403" do
        put :move_legacy, params: {
                            project_id: project.id,
                            sprint_id: version_sprint.id,
                            id: story.id,
                            target_id: "foo",
                            position: 1
                          },
                          format: :turbo_stream

        expect(response).not_to be_successful
        expect(response).to have_http_status :not_found
      end
    end

    context "with a version from the same project" do
      let(:other_version_sprint) { create(:sprint, name: "Sprint 2", project:) }

      it "responds with success", :aggregate_failures do
        put :move_legacy, params: {
                            project_id: project.id,
                            sprint_id: version_sprint.id,
                            id: story.id,
                            target_id: "version:#{other_version_sprint.id}",
                            position: 1
                          },
                          format: :turbo_stream

        expect(response).to be_successful
        expect(response).to have_http_status :ok
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-backlog-component-#{version_sprint.id}"
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-backlog-component-#{other_version_sprint.id}"
        assert_select %(turbo-stream[action="replace"][target="backlogs-backlog-component-#{version_sprint.id}"][method="morph"])
        assert_select %(turbo-stream[action="replace"][target="backlogs-backlog-component-#{other_version_sprint.id}"][method="morph"]) # rubocop:disable Layout/LineLength
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        expect(assigns(:project)).to eq(project)
        expect(assigns(:sprint)).to eq(version_sprint)
        expect(assigns(:story)).to eq(story)
        expect(assigns(:backlog)).to be_a(Backlog)
      end
    end

    context "with a version from another project" do
      let(:other_project) { create(:project) }
      let(:other_version_sprint) { create(:sprint, name: "Sprint 2", project: other_project, sharing: "system") }
      let(:story) { create(:story, status:, version: other_version_sprint, project:) }

      it "responds with success", :aggregate_failures do
        put :move_legacy, params: {
                            project_id: project.id,
                            sprint_id: other_version_sprint.id,
                            id: story.id,
                            target_id: "version:#{version_sprint.id}",
                            position: 1
                          },
                          format: :turbo_stream

        expect(response).to be_successful
        expect(response).to have_http_status :ok
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-backlog-component-#{other_version_sprint.id}"
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-backlog-component-#{version_sprint.id}"
        assert_select %(turbo-stream[action="replace"][target="backlogs-backlog-component-#{other_version_sprint.id}"][method="morph"]) # rubocop:disable Layout/LineLength
        assert_select %(turbo-stream[action="replace"][target="backlogs-backlog-component-#{version_sprint.id}"][method="morph"])
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        expect(assigns(:project)).to eq(project)
        expect(assigns(:sprint)).to eq(other_version_sprint)
        expect(assigns(:story)).to eq(story)
        expect(assigns(:backlog)).to be_a(Backlog)
      end
    end

    context "when service call fails" do
      let(:other_version_sprint) { create(:sprint, name: "Sprint 2", project:) }
      let(:service_result) { ServiceResult.failure(message: "Something went wrong") }

      before do
        update_service = instance_double(Stories::UpdateService, call: service_result)

        allow(Stories::UpdateService)
          .to receive(:new)
          .and_return(update_service)
      end

      it "renders an error flash with 422", :aggregate_failures do
        put :move_legacy, params: {
                            project_id: project.id,
                            sprint_id: version_sprint.id,
                            id: story.id,
                            target_id: "version:#{other_version_sprint.id}",
                            position: 1
                          },
                          format: :turbo_stream

        expect(response).to have_http_status :unprocessable_entity
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        expect(response).not_to have_turbo_stream action: "replace", target: "backlogs-backlog-component-#{version_sprint.id}"
      end
    end
  end

  describe "POST #reorder" do
    it "responds with success", :aggregate_failures do
      post :reorder, params: { project_id: project.id, sprint_id: version_sprint.id, id: story.id, direction: "highest" },
                     format: :turbo_stream

      expect(response).to be_successful
      expect(response).to have_http_status :ok
      expect(response).to have_turbo_stream action: "replace", target: "backlogs-backlog-component-#{version_sprint.id}"
      assert_select %(turbo-stream[action="replace"][target="backlogs-backlog-component-#{version_sprint.id}"][method="morph"])
      expect(assigns(:project)).to eq(project)
      expect(assigns(:sprint)).to eq(version_sprint)
      expect(assigns(:story)).to eq(story)
      expect(assigns(:backlog)).to be_a(Backlog)
    end

    context "when service call fails" do
      let(:service_result) { ServiceResult.failure(message: "Something went wrong") }

      before do
        update_service = instance_double(Stories::UpdateService, call: service_result)

        allow(Stories::UpdateService)
          .to receive(:new)
          .and_return(update_service)
      end

      it "renders an error flash with 422", :aggregate_failures do
        post :reorder, params: { project_id: project.id, sprint_id: version_sprint.id, id: story.id, direction: "highest" },
                       format: :turbo_stream

        expect(response).to have_http_status :unprocessable_entity
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        expect(response).not_to have_turbo_stream action: "replace", target: "backlogs-backlog-component-#{version_sprint.id}"
      end
    end
  end

  describe "PUT #move", with_flag: { scrum_projects: true } do
    let(:agile_sprint) { create(:agile_sprint, name: "Agile Sprint 1", project:) }
    let(:story_in_agile_sprint) { create(:work_package, status:, sprint: agile_sprint, project:) }

    context "with another Agile::Sprint as target", with_flag: { scrum_projects: true } do
      let(:other_agile_sprint) { create(:agile_sprint, name: "Agile Sprint 2", project:) }

      it "responds with success and moves story to another Agile::Sprint", :aggregate_failures do
        put :move, params: {
                     project_id: project.id,
                     sprint_id: agile_sprint.id,
                     id: story_in_agile_sprint.id,
                     target_id: "sprint:#{other_agile_sprint.id}",
                     position: 1
                   },
                   format: :turbo_stream

        expect(response).to be_successful
        expect(response).to have_http_status :ok
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-sprint-component-#{agile_sprint.id}"
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-sprint-component-#{other_agile_sprint.id}"
        assert_select %(turbo-stream[action="replace"][target="backlogs-sprint-component-#{agile_sprint.id}"])
        assert_select %(turbo-stream[action="replace"][target="backlogs-sprint-component-#{other_agile_sprint.id}"])
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        expect(assigns(:project)).to eq(project)
        expect(assigns(:sprint)).to eq(agile_sprint)
        expect(assigns(:story)).to eq(story_in_agile_sprint)
      end

      context "when the story has a version that is not used as backlog" do
        let(:story_in_agile_sprint) { create(:work_package, status:, sprint: agile_sprint, version: version_sprint, project:) }
        # Via this setting, version_sprint is NOT used as backlog:
        let!(:version_setting) { create(:version_setting, version: version_sprint, project:, display: VersionSetting::DISPLAY_NONE) }

        it "responds with success and moves story to Agile::Sprint, keeping the version", :aggregate_failures do
          put :move, params: {
                       project_id: project.id,
                       sprint_id: agile_sprint.id,
                       id: story_in_agile_sprint.id,
                       target_id: "sprint:#{other_agile_sprint.id}",
                       position: 1
                     },
                     format: :turbo_stream

          expect(response).to be_successful
          expect(response).to have_http_status :ok
          expect(response).to have_turbo_stream action: "replace", target: "backlogs-sprint-component-#{agile_sprint.id}"
          expect(response).to have_turbo_stream action: "replace", target: "backlogs-sprint-component-#{other_agile_sprint.id}"
          assert_select %(turbo-stream[action="replace"][target="backlogs-sprint-component-#{agile_sprint.id}"])
          assert_select %(turbo-stream[action="replace"][target="backlogs-sprint-component-#{other_agile_sprint.id}"])
          expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
          expect(assigns(:project)).to eq(project)
          expect(assigns(:sprint)).to eq(agile_sprint)
          expect(assigns(:story)).to eq(story_in_agile_sprint)

          # It will preserve the version since it is not used as backlog/sprint.
          expect(story_in_agile_sprint.reload.version).to eq(version_sprint)
        end
      end
    end

    context "with a Sprint (Version) as target", with_flag: { scrum_projects: true } do
      it "responds with success and moves story to Sprint", :aggregate_failures do
        put :move, params: {
                     project_id: project.id,
                     sprint_id: agile_sprint.id,
                     id: story_in_agile_sprint.id,
                     target_id: "version:#{version_sprint.id}",
                     position: 1
                   },
                   format: :turbo_stream

        expect(response).to be_successful
        expect(response).to have_http_status :ok
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-sprint-component-#{agile_sprint.id}"
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-backlog-component-#{version_sprint.id}"
        assert_select %(turbo-stream[action="replace"][target="backlogs-sprint-component-#{agile_sprint.id}"])
        assert_select %(turbo-stream[action="replace"][target="backlogs-backlog-component-#{version_sprint.id}"][method="morph"])
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        expect(assigns(:project)).to eq(project)
        expect(assigns(:sprint)).to eq(agile_sprint)
        expect(assigns(:story)).to eq(story_in_agile_sprint)
        expect(assigns(:backlog)).to be_a(Backlog)
      end
    end

    context "with Inbox as target" do
      let!(:existing_inbox_item) { create(:work_package, project:, status:, position: 1) }

      it "responds with success and moves story to Inbox at the given position", :aggregate_failures do
        put :move, params: {
                     project_id: project.id,
                     sprint_id: agile_sprint.id,
                     id: story_in_agile_sprint.id,
                     target_id: "inbox",
                     position: 2
                   },
                   format: :turbo_stream

        expect(response).to be_successful
        expect(response).to have_http_status :ok
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-sprint-component-#{agile_sprint.id}"
        expect(response).to have_turbo_stream action: "replace", target: "backlogs-inbox-component-#{project.id}"
        assert_select %(turbo-stream[action="replace"][target="backlogs-sprint-component-#{agile_sprint.id}"])
        assert_select %(turbo-stream[action="replace"][target="backlogs-inbox-component-#{project.id}"][method="morph"])
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        expect(assigns(:project)).to eq(project)
        expect(assigns(:sprint)).to eq(agile_sprint)
        expect(assigns(:story)).to eq(story_in_agile_sprint)
        expect(story_in_agile_sprint.reload.sprint).to be_nil
        expect(story_in_agile_sprint.reload.position).to eq(2)
      end
    end

    context "when service call fails" do
      let(:other_agile_sprint) { create(:agile_sprint, name: "Agile Sprint 2", project:) }
      let(:service_result) { ServiceResult.failure(message: "Something went wrong") }

      before do
        update_service = instance_double(Stories::UpdateService, call: service_result)

        allow(Stories::UpdateService)
          .to receive(:new)
          .and_return(update_service)
      end

      it "renders an error flash with 422", :aggregate_failures do
        put :move, params: {
                     project_id: project.id,
                     sprint_id: agile_sprint.id,
                     id: story_in_agile_sprint.id,
                     target_id: "sprint:#{other_agile_sprint.id}",
                     position: 1
                   },
                   format: :turbo_stream

        expect(response).to have_http_status :unprocessable_entity
        expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
        expect(response).not_to have_turbo_stream action: "replace", target: "backlogs-sprint-component-#{agile_sprint.id}"
      end
    end
  end
end
