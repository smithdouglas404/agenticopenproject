# frozen_string_literal: true

# -- copyright
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
# ++
#

require "spec_helper"

RSpec.describe Admin::Import::Jira::ImportRunsController do
  shared_let(:admin) { create(:admin) }
  shared_let(:non_admin) { create(:user) }
  shared_let(:jira) { create(:jira) }

  # Walks a JiraImport through the state machine to reach the target state.
  # All after_transition job callbacks are stubbed.
  def transition_to_state(jira_import, target_state)
    gu_prefix = %w[instance_meta_fetching instance_meta_done groups_and_users_init
                   groups_and_users_fetching groups_and_users_fetching_done
                   groups_and_users_importing groups_and_users_importing_done import_scope]

    paths = {
      "initial" => [],
      "instance_meta_fetching" => %w[instance_meta_fetching],
      "instance_meta_error" => %w[instance_meta_fetching instance_meta_error],
      "instance_meta_done" => %w[instance_meta_fetching instance_meta_done],
      "groups_and_users_init" => %w[instance_meta_fetching instance_meta_done groups_and_users_init],
      "groups_and_users_fetching" => %w[instance_meta_fetching instance_meta_done groups_and_users_init
                                        groups_and_users_fetching],
      "groups_and_users_fetching_error" => %w[instance_meta_fetching instance_meta_done groups_and_users_init
                                              groups_and_users_fetching groups_and_users_fetching_error],
      "groups_and_users_fetching_done" => %w[instance_meta_fetching instance_meta_done groups_and_users_init
                                             groups_and_users_fetching groups_and_users_fetching_done],
      "groups_and_users_importing" => %w[instance_meta_fetching instance_meta_done groups_and_users_init
                                         groups_and_users_fetching groups_and_users_fetching_done
                                         groups_and_users_importing],
      "groups_and_users_importing_error" => %w[instance_meta_fetching instance_meta_done groups_and_users_init
                                               groups_and_users_fetching groups_and_users_fetching_done
                                               groups_and_users_importing groups_and_users_importing_error],
      "groups_and_users_importing_done" => %w[instance_meta_fetching instance_meta_done groups_and_users_init
                                              groups_and_users_fetching groups_and_users_fetching_done
                                              groups_and_users_importing groups_and_users_importing_done],
      "import_scope" => gu_prefix,
      "configuring" => gu_prefix + %w[configuring],
      "projects_meta_fetching" => gu_prefix + %w[configuring projects_meta_fetching],
      "projects_meta_error" => gu_prefix + %w[configuring projects_meta_fetching projects_meta_error],
      "projects_meta_done" => gu_prefix + %w[configuring projects_meta_fetching projects_meta_done],
      "importing" => gu_prefix + %w[configuring projects_meta_fetching projects_meta_done importing],
      "import_error" => gu_prefix + %w[configuring projects_meta_fetching projects_meta_done importing import_error],
      "imported" => gu_prefix + %w[configuring projects_meta_fetching projects_meta_done importing imported],
      "completed" => gu_prefix + %w[configuring projects_meta_fetching projects_meta_done importing imported completed],
      "reverting" => gu_prefix + %w[configuring projects_meta_fetching projects_meta_done importing imported reverting],
      "revert_error" => gu_prefix + %w[configuring projects_meta_fetching projects_meta_done
                                       importing imported reverting revert_error],
      "reverted" => gu_prefix + %w[configuring projects_meta_fetching projects_meta_done
                                   importing imported reverting reverted]
    }

    steps = paths.fetch(target_state.to_s)
    steps.each { |state| jira_import.transition_to!(state.to_sym) }
  end

  before do
    login_as(admin)
    allow(Import::JiraInstanceMetaDataJob).to receive(:perform_later).and_return(double(job_id: "job-stub"))
    allow(Import::JiraProjectsMetaDataJob).to receive(:perform_later).and_return(double(job_id: "job-stub"))
    allow(Import::JiraFetchAndImportProjectsJob).to receive(:perform_later).and_return(double(job_id: "job-stub"))
    allow(Import::JiraRevertImportJob).to receive(:perform_later).and_return(double(job_id: "job-stub"))
    allow(Import::JiraFetchGroupsAndUsersJob).to receive(:perform_later).and_return(double(job_id: "job-stub"))
    allow(Import::JiraImportGroupsAndUsersJob).to receive(:perform_later).and_return(double(job_id: "job-stub"))
  end

  context "when user is not an admin" do
    let(:jira_import) { create(:jira_import, jira:, author: admin) }

    before { login_as(non_admin) }

    it "returns forbidden for GET #show" do
      get :show, params: { jira_id: jira.id, id: jira_import.id }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns forbidden for GET #new" do
      get :new, params: { jira_id: jira.id }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns forbidden for POST #continue" do
      post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "init" }, format: :turbo_stream
      expect(response).to have_http_status(:forbidden)
    end

    it "returns forbidden for GET #revert_modal" do
      get :revert_modal, params: { jira_id: jira.id, id: jira_import.id }, format: :turbo_stream
      expect(response).to have_http_status(:forbidden)
    end

    it "returns forbidden for GET #finalize_modal" do
      get :finalize_modal, params: { jira_id: jira.id, id: jira_import.id }, format: :turbo_stream
      expect(response).to have_http_status(:forbidden)
    end

    it "returns forbidden for DELETE #remove" do
      delete :remove, params: { jira_id: jira.id, id: jira_import.id }
      expect(response).to have_http_status(:forbidden)
    end

    it "returns forbidden for GET #history" do
      get :history, params: { jira_id: jira.id, id: jira_import.id }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET #show" do
    let(:jira_import) { create(:jira_import, jira:, author: admin) }

    it "renders the show template" do
      get :show, params: { jira_id: jira.id, id: jira_import.id }
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET #new" do
    it "creates a new jira import and redirects to show" do
      expect do
        get :new, params: { jira_id: jira.id }
      end.to change(Import::JiraImport, :count).by(1)

      new_import = Import::JiraImport.last
      expect(new_import.author).to eq(admin)
      expect(new_import.jira).to eq(jira)
      expect(new_import.current_state).to eq("initial")
      expect(response).to redirect_to(admin_import_jira_run_path(jira_id: jira.id, id: new_import.id))
    end
  end

  describe "GET/POST #continue" do
    let(:jira_import) { create(:jira_import, jira:, author: admin) }

    context "when step is fetch_instance_meta" do
      it "transitions to instance_meta_fetching and triggers the job" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "fetch_instance_meta" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("instance_meta_fetching")
        expect(Import::JiraInstanceMetaDataJob).to have_received(:perform_later).with(jira_import.id)
      end
    end

    context "when step is fetch_groups_and_users" do
      before { transition_to_state(jira_import, "groups_and_users_init") }

      it "transitions to groups_and_users_fetching and triggers the job" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "fetch_groups_and_users" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("groups_and_users_fetching")
        expect(Import::JiraFetchGroupsAndUsersJob).to have_received(:perform_later).with(jira_import.id)
      end
    end

    context "when step is fetch_groups_and_users from groups_and_users_fetching_error" do
      before { transition_to_state(jira_import, "groups_and_users_fetching_error") }

      it "retries groups and users fetching" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "fetch_groups_and_users" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("groups_and_users_fetching")
        expect(Import::JiraFetchGroupsAndUsersJob).to have_received(:perform_later).with(jira_import.id).twice
      end
    end

    context "when step is import_groups_and_users" do
      before { transition_to_state(jira_import, "groups_and_users_fetching_done") }

      it "transitions to groups_and_users_importing and triggers the job" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "import_groups_and_users" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("groups_and_users_importing")
        expect(Import::JiraImportGroupsAndUsersJob).to have_received(:perform_later).with(jira_import.id)
      end
    end

    context "when step is import_groups_and_users from groups_and_users_importing_error" do
      before { transition_to_state(jira_import, "groups_and_users_importing_error") }

      it "retries groups and users importing" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "import_groups_and_users" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("groups_and_users_importing")
        expect(Import::JiraImportGroupsAndUsersJob).to have_received(:perform_later).with(jira_import.id).twice
      end
    end

    context "when step is import_scope" do
      before { transition_to_state(jira_import, "groups_and_users_importing_done") }

      it "transitions to import_scope" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "import_scope" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("import_scope")
      end
    end

    context "when step is configure" do
      before { transition_to_state(jira_import, "import_scope") }

      it "transitions to configuring" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "configure" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("configuring")
      end
    end

    context "when step is fetch_projects_meta" do
      before { transition_to_state(jira_import, "configuring") }

      it "transitions to projects_meta_fetching and triggers the job" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "fetch_projects_meta" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("projects_meta_fetching")
        expect(Import::JiraProjectsMetaDataJob).to have_received(:perform_later).with(jira_import.id)
      end
    end

    context "when step is fetch_projects_meta from projects_meta_error" do
      before { transition_to_state(jira_import, "projects_meta_error") }

      it "retries projects meta fetching" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "fetch_projects_meta" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("projects_meta_fetching")
        expect(Import::JiraProjectsMetaDataJob).to have_received(:perform_later).with(jira_import.id).twice
      end
    end

    context "when step is import" do
      before { transition_to_state(jira_import, "projects_meta_done") }

      it "transitions to importing and triggers the job" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "import" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("importing")
        expect(Import::JiraFetchAndImportProjectsJob).to have_received(:perform_later).with(jira_import.id)
      end
    end

    context "when step is import from import_error" do
      before { transition_to_state(jira_import, "import_error") }

      it "retries the import" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "import" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("importing")
        expect(Import::JiraFetchAndImportProjectsJob).to have_received(:perform_later).with(jira_import.id).twice
      end
    end

    context "when step is revert" do
      before { transition_to_state(jira_import, "imported") }

      it "transitions to reverting and triggers the job" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "revert" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("reverting")
        expect(Import::JiraRevertImportJob).to have_received(:perform_later).with(jira_import.id)
      end
    end

    context "when step is revert from revert_error" do
      before { transition_to_state(jira_import, "revert_error") }

      it "retries the revert" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "revert" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("reverting")
        expect(Import::JiraRevertImportJob).to have_received(:perform_later).with(jira_import.id).twice
      end
    end

    context "when step is finalize" do
      before { transition_to_state(jira_import, "imported") }

      it "transitions to completed" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "finalize" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("completed")
      end
    end

    context "when step is blank" do
      it "does not change state" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("initial")
        expect(response).to have_http_status(:ok)
      end
    end

    context "when step is invalid" do
      it "handles the error with turbo_stream flash message" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "invalid_step" }, format: :turbo_stream
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("Invalid step: invalid_step")
      end
    end

    context "when import is running (status_running? is true)" do
      before { transition_to_state(jira_import, "importing") }

      it "does not change the step" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "finalize" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("importing")
      end
    end

    context "when transition is invalid for current state" do
      before { transition_to_state(jira_import, "imported") }

      it "handles the transition error via turbo_stream" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "init" }, format: :turbo_stream
        expect(jira_import.current_state).to eq("imported")
        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end
    end

    context "when an error occurs" do
      before do
        allow(controller).to receive(:change_step).and_raise(StandardError.new("Test error"))
      end

      it "handles the error with turbo_stream" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "finalize" }, format: :turbo_stream
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Test error")
      end

      it "handles the error with html format" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "finalize" }, format: :html
        expect(flash[:error]).to eq("Test error")
        expect(response).to redirect_to(admin_import_jira_run_path(jira_id: jira.id, id: jira_import.id))
      end
    end

    context "when requesting html format" do
      before { transition_to_state(jira_import, "imported") }

      it "redirects to show page" do
        post :continue, params: { jira_id: jira.id, id: jira_import.id, step: "finalize" }, format: :html
        expect(response).to redirect_to(admin_import_jira_run_path(jira_id: jira.id, id: jira_import.id))
      end
    end
  end

  describe "GET #revert_modal" do
    let(:jira_import) { create(:jira_import, jira:, author: admin) }

    it "responds with a dialog component" do
      get :revert_modal, params: { jira_id: jira.id, id: jira_import.id }, format: :turbo_stream
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET #finalize_modal" do
    let(:jira_import) { create(:jira_import, jira:, author: admin) }

    it "responds with a dialog component" do
      get :finalize_modal, params: { jira_id: jira.id, id: jira_import.id }, format: :turbo_stream
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET #history" do
    let(:jira_import) { create(:jira_import, jira:, author: admin) }

    it "assigns the history" do
      transition_to_state(jira_import, "instance_meta_fetching")
      get :history, params: { jira_id: jira.id, id: jira_import.id }
      expect(response).to have_http_status(:ok)
      expect(assigns(:history)).to be_present
    end
  end

  describe "DELETE #remove" do
    let!(:jira_import) { create(:jira_import, jira:, author: admin) }

    it "destroys the jira import and redirects" do
      expect do
        delete :remove, params: { jira_id: jira.id, id: jira_import.id }
      end.to change(Import::JiraImport, :count).by(-1)
      expect(response).to redirect_to(admin_import_jira_path(jira))
    end

    context "when import is running" do
      before { transition_to_state(jira_import, "importing") }

      it "raises an error" do
        expect do
          delete :remove, params: { jira_id: jira.id, id: jira_import.id }
        end.to raise_error(StandardError, I18n.t("admin.jira.run.remove_error"))
      end
    end
  end
end
