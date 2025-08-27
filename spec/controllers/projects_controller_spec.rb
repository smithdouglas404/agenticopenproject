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

RSpec.describe ProjectsController do
  shared_let(:admin) { create(:admin) }

  let(:user) { admin }

  before do
    allow(controller).to receive(:set_localization)

    login_as user
  end

  describe "#new" do
    shared_examples_for "successful requests" do
      context "without a parent" do
        let(:parent) { nil }

        context "without a template" do
          let(:template) { nil }

          it_behaves_like "successful request"
        end

        context "with a template" do
          let(:template) { create(:template_project) }

          it_behaves_like "successful request"
        end
      end

      context "with a parent" do
        let(:parent) { create(:project) }

        context "without a template" do
          let(:template) { nil }

          it_behaves_like "successful request"
        end

        context "with a template" do
          let(:template) { create(:template_project) }

          it_behaves_like "successful request"
        end
      end
    end

    shared_examples_for "successful request" do
      it "renders 'new'", :aggregate_failures do
        expect(response).to be_successful
        expect(assigns(:new_project)).to be_a_new(Project)
        expect(assigns(:parent)).to eq parent
        expect(assigns(:template)).to eq template
        expect(response).to render_template "new"
      end
    end

    before do
      get :new, params: { parent_id: parent&.id, template_id: template&.id }
    end

    context "as an admin" do
      it_behaves_like "successful requests"
    end

    context "as a non-admin with global add_project permission" do
      let(:user) { create(:user, global_permissions: [:add_project]) }
      let(:template) { nil }

      context "without a parent" do
        let(:parent) { nil }

        it_behaves_like "successful request"
      end

      context "with a parent with public permissions" do
        let(:user) { create(:user, global_permissions: [:add_project], member_with_permissions: { parent => [] }) }
        let(:parent) { create(:project) }

        it_behaves_like "successful request"
      end
    end

    context "as a non-admin without global add_project permission" do
      let(:user) { create(:user, global_permissions: []) }
      let(:template) { nil }

      context "without a parent" do
        let(:parent) { nil }

        it "returns 403 Not Authorized" do
          expect(response).not_to be_successful
          expect(response).to have_http_status :forbidden
        end
      end

      context "with a parent with add_subprojects permissions" do
        let(:user) { create(:user, member_with_permissions: { parent => [:add_subprojects] }) }
        let(:parent) { create(:project) }
        let(:template) { nil }

        it_behaves_like "successful request"
      end
    end

    context "as a non-admin with global add_portfolios permission", with_flag: { portfolio_models: true } do
      let(:parent) { nil }
      let(:user) { create(:user, global_permissions: [:add_portfolios]) }
      let(:template) { nil }

      it_behaves_like "successful request"
    end

    context "as a non-admin with global add_programs permission", with_flag: { portfolio_models: true } do
      let(:parent) { nil }
      let(:user) { create(:user, global_permissions: [:add_programs]) }
      let(:template) { nil }

      it_behaves_like "successful request"
    end
  end

  describe "#create" do
    describe "permission checks" do
      let(:project) { build_stubbed(:project) }
      let(:service_result) { ServiceResult.success(result: project) }
      let(:parent) { nil }

      before do
        creation_service = instance_double(Projects::CreateService, call: service_result)

        allow(Projects::CreateService)
          .to receive(:new)
                .with(user:)
                .and_return(creation_service)

        post :create, params: { project: { name: "New Project" }, parent_id: parent&.id }
      end

      shared_examples_for "successful create request" do
        it "redirects to project show", :aggregate_failures do
          expect(response).to redirect_to project_path(project)
          expect(flash[:notice]).to eq I18n.t(:notice_successful_create)
        end
      end

      shared_examples_for "forbidden create request" do
        it "returns 403 Not Authorized" do
          expect(response).not_to be_successful
          expect(response).to have_http_status :forbidden
        end
      end

      context "as an admin" do
        it_behaves_like "successful create request"

        context "with a parent" do
          let(:parent) { create(:project) }

          it_behaves_like "successful create request"
        end
      end

      context "as a non-admin with global add_project permission" do
        let(:user) { create(:user, global_permissions: [:add_project]) }

        it_behaves_like "successful create request"

        context "with a parent with public permissions" do
          let(:user) { create(:user, global_permissions: [:add_project], member_with_permissions: { parent => [] }) }
          let(:parent) { create(:project) }

          it_behaves_like "successful create request"
        end
      end

      context "as a non-admin without global add_project permission" do
        let(:user) { create(:user, global_permissions: []) }

        it_behaves_like "forbidden create request"

        context "with a parent with add_subprojects permissions" do
          let(:user) { create(:user, member_with_permissions: { parent => [:add_subprojects] }) }
          let(:parent) { create(:project) }

          it_behaves_like "successful create request"
        end
      end

      context "as a non-admin with global add_portfolios permission", with_flag: { portfolio_models: true } do
        let(:user) { create(:user, global_permissions: [:add_portfolios]) }

        it_behaves_like "successful create request"
      end

      context "as a non-admin with global add_programs permission", with_flag: { portfolio_models: true } do
        let(:user) { create(:user, global_permissions: [:add_programs]) }

        it_behaves_like "successful create request"
      end
    end

    context "without a template" do
      before do
        creation_service = instance_double(Projects::CreateService, call: service_result)

        allow(Projects::CreateService)
          .to receive(:new)
                .with(user: admin)
                .and_return(creation_service)
      end

      context "when service call succeeds" do
        let(:project) { build_stubbed(:project) }
        let(:service_result) { ServiceResult.success(result: project) }

        it "redirects to project show", :aggregate_failures do
          post :create, params: { project: { name: "New Project" } }

          expect(response).to redirect_to project_path(project)
          expect(flash[:notice]).to eq I18n.t(:notice_successful_create)
        end
      end

      context "when service call fails" do
        let(:project) { Project.new }
        let(:service_result) { ServiceResult.failure(result: project, message: "") }

        it "renders new template with errors", :aggregate_failures do
          post :create, params: { project: { name: "" } }

          expect(response).not_to be_successful
          expect(response).to have_http_status :unprocessable_entity
          expect(assigns(:new_project)).to be_a_new(Project)
          expect(assigns(:new_project)).not_to be_valid
          expect(flash[:error]).to start_with I18n.t(:notice_unsuccessful_create_with_reason, reason: "")
          expect(response).to render_template "new"
        end
      end
    end

    context "with a template" do
      let(:template) { create(:template_project) }

      before do
        copy_service = instance_double(Projects::EnqueueCopyService)

        allow(Projects::EnqueueCopyService)
         .to receive(:new)
               .with(user: admin, model: template)
               .and_return(copy_service)

        allow(copy_service)
          .to receive(:call)
              .with(target_project_params: { "name" => name }, only: [], send_notifications: false)
              .and_return(service_result)

        post :create, params: {
          template_id: template.id,
          project: { name: },
          copy_options: { dependencies: [""], send_notifications: false } # emulating empty dependencies array
        }
      end

      context "when service call succeeds" do
        let(:name) { "Copied project" }
        let(:job) { CopyProjectJob.new }
        let(:service_result) { ServiceResult.success(result: job) }

        it "redirects to job status", :aggregate_failures do
          expect(response).to redirect_to job_status_path(job.job_id)
        end
      end

      context "when service call fails" do
        let(:name) { "" }
        let(:project) { Project.new }
        let(:service_result) { ServiceResult.failure(result: project, message: "") }

        it "renders new template with errors", :aggregate_failures do
          expect(response).not_to be_successful
          expect(response).to have_http_status :unprocessable_entity
          expect(assigns(:new_project)).to be_a_new(Project)
          expect(assigns(:new_project)).not_to be_valid
          expect(assigns(:template)).not_to be_nil
          expect(assigns(:copy_options)).not_to be_nil
          expect(flash[:error]).to start_with I18n.t(:notice_unsuccessful_create_with_reason, reason: "")
          expect(response).to render_template "new"
        end
      end
    end
  end

  describe "index.html" do
    shared_let(:project_a) { create(:project, name: "Project A", public: false, active: true) }
    shared_let(:project_b) { create(:project, name: "Project B", public: false, active: true) }
    shared_let(:project_c) { create(:project, name: "Project C", public: true, active: true) }
    shared_let(:project_d) { create(:project, name: "Project D", public: true, active: false) }

    before do
      ProjectRole.anonymous
      ProjectRole.non_member

      login_as(user)
      get "index"
    end

    shared_examples_for "successful index" do
      it "is success" do
        expect(response).to be_successful
      end

      it "renders the index template" do
        expect(response).to render_template "index"
      end
    end
  end

  describe "#destroy" do
    render_views

    let(:project) { build_stubbed(:project) }
    let(:request) { delete :destroy, params: { id: project.id } }

    let(:service_result) { ServiceResult.new(success:) }

    before do
      allow(Project).to receive(:find).and_return(project)
      deletion_service = instance_double(Projects::ScheduleDeletionService,
                                         call: service_result)

      allow(Projects::ScheduleDeletionService)
        .to receive(:new)
              .with(user: admin, model: project)
              .and_return(deletion_service)
    end

    context "when service call succeeds" do
      let(:success) { true }

      it "prints success" do
        request
        expect(response).to be_redirect
        expect(flash[:notice]).to be_present
      end
    end

    context "when service call fails" do
      let(:success) { false }

      it "prints fail" do
        request
        expect(response).to be_redirect
        expect(flash[:error]).to be_present
      end
    end
  end

  describe "with an existing project" do
    let(:project) { create(:project, identifier: "blog") }

    it "gets destroy info" do
      get :destroy_info, params: { id: project.id }
      expect(response).to be_successful
      expect(response).to render_template "destroy_info"

      expect { project.reload }.not_to raise_error
    end
  end

  describe "#copy_form" do
    let(:project) { create(:project, identifier: "blog") }

    shared_examples_for "successful request" do
      it "renders 'copy_form'", :aggregate_failures do
        expect(response).to be_successful
        expect(assigns(:target_project)).to be_a_new(Project)
        expect(assigns(:project)).to eq project
        expect(response).to render_template "copy_form"
      end
    end

    before do
      get "copy_form", params: { id: project.identifier }
    end

    context "as an admin" do
      it_behaves_like "successful request"
    end

    context "as a non-admin with copy_projects permissions" do
      let(:user) { create(:user, member_with_permissions: { project => [:copy_projects] }) }

      it_behaves_like "successful request"
    end

    context "as a non-admin without copy_projects permissions" do
      let(:user) { build_stubbed(:user) }

      it "returns 403 Not Authorized" do
        expect(response).not_to be_successful
        expect(response).to have_http_status :forbidden
      end
    end
  end

  describe "#copy" do
    let(:project) { create(:project, identifier: "blog") }

    before do
      copy_service = instance_double(Projects::EnqueueCopyService)

      allow(Projects::EnqueueCopyService)
       .to receive(:new)
             .with(user: admin, model: project)
             .and_return(copy_service)

      allow(copy_service)
        .to receive(:call)
            .with(target_project_params: { "name" => name }, only: [], send_notifications: false)
            .and_return(service_result)

      post :copy, params: {
        id: project.identifier,
        project: { name: },
        copy_options: { dependencies: [""], send_notifications: false } # emulating empty dependencies array
      }
    end

    context "when service call succeeds" do
      let(:name) { "Copied project" }
      let(:job) { CopyProjectJob.new }
      let(:service_result) { ServiceResult.success(result: job) }

      it "redirects to job status" do
        expect(response).to redirect_to job_status_path(job.job_id)
      end
    end

    context "when service call fails" do
      let(:name) { "" }
      let(:target_project) { Project.new }
      let(:service_result) { ServiceResult.failure(result: target_project, message: "") }

      it "renders copy_form template with errors", :aggregate_failures do
        expect(response).not_to be_successful
        expect(response).to have_http_status :unprocessable_entity
        expect(assigns(:target_project)).to be_a_new(Project)
        expect(assigns(:target_project)).not_to be_valid
        expect(assigns(:project)).to eq project
        expect(assigns(:copy_options)).not_to be_nil
        expect(flash[:error]).to start_with I18n.t(:notice_unsuccessful_create_with_reason, reason: "")
        expect(response).to render_template "copy_form"
      end
    end
  end
end
