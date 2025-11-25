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

RSpec.describe Projects::CreateArtifactWorkPackageService do
  shared_let(:status_new) { create(:status, name: "New") }
  shared_let(:type) { create(:type, name: "Project initiation") }
  shared_let(:user_custom_field) { create(:user_project_custom_field, name: "Project Manager") }
  shared_let(:assignee_user) { create(:user, firstname: "assignee_user") }
  shared_let(:current_user) { create(:user, lastname: "current_user") }
  shared_let(:role) do
    create(:project_role, permissions: %i[
             add_work_packages
             view_project_attributes
             work_package_assigned
           ])
  end
  shared_let(:default_priority) { create(:default_priority) }
  shared_let(:project) do
    create(
      :project,
      name: "Important Project",
      types: [type],
      project_custom_fields: [user_custom_field],
      # project initiation request settings
      project_creation_wizard_artifact_name: "project_mandate",
      project_creation_wizard_enabled: true,
      project_creation_wizard_work_package_type_id: type.id,
      project_creation_wizard_status_when_submitted_id: status_new.id,
      project_creation_wizard_assignee_custom_field_id: user_custom_field.id,
      project_creation_wizard_work_package_comment: "PIR submitted for **Project Name**.",
      user_custom_field.attribute_name => assignee_user.id
    ).tap do |p|
      p.members << create(:member, principal: assignee_user, project: p, roles: [role])
      p.members << create(:member, principal: current_user, project: p, roles: [role])
    end
  end

  let(:mocked_contract) { instance_double(Projects::CreateArtifactWorkPackageContract, "mocked_contract") }
  let(:instance) do
    described_class.new(user: current_user, model: project).tap do |instance|
      allow(instance).to receive(:instantiate_contract).and_return(mocked_contract)
    end
  end

  before do
    login_as current_user
  end

  context "when contract is valid" do
    before do
      allow(mocked_contract).to receive(:validate).and_return(true)
    end

    it "creates an artifact work package (for after submitting a project initiation request)" do
      result = instance.call

      expect(result.errors.full_messages).to be_empty
      project = result.result
      expect(project.project_creation_wizard_artifact_work_package_id).to be_present
    end

    it "uses the type and status defined in the project initiation request settings" do
      result = instance.call
      project = result.result
      artifact_work_package = WorkPackage.find(project.project_creation_wizard_artifact_work_package_id)
      expect(artifact_work_package.type.id).to eq(project.project_creation_wizard_work_package_type_id)
      expect(artifact_work_package.status.id).to eq(project.project_creation_wizard_status_when_submitted_id)
    end

    it "assigns the artifact work package to the user pointed by the 'Assignee when submitted' custom field" do
      result = instance.call
      project = result.result

      artifact_work_package = WorkPackage.find(project.project_creation_wizard_artifact_work_package_id)
      expect(artifact_work_package.assigned_to).to eq(assignee_user)
    end

    it "attaches the project initiation request pdf file to the artifact work package" do
      result = instance.call
      project = result.result

      artifact_work_package = WorkPackage.find(project.project_creation_wizard_artifact_work_package_id)
      expect(artifact_work_package.attachments.count).to eq(1)

      attachment = artifact_work_package.attachments.first
      expect(attachment.file.content_type).to eq("application/pdf")
      expect(attachment.author).to eq(current_user)
    end

    it "sets the subject to the artifact name configured in the project initiation request settings" do
      result = instance.call
      project = result.result

      artifact_work_package = WorkPackage.find(project.project_creation_wizard_artifact_work_package_id)
      expected_name = I18n.t("settings.project_initiation_request.name.options.#{project.project_creation_wizard_artifact_name}")
      expect(artifact_work_package.subject).to eq(expected_name)
    end

    it "if the artifact name is misconfigured (unexisting name key), " \
       "sets the subject to the 'project_creation_wizard' artifact name" do
      project.update(project_creation_wizard_artifact_name: "misconfigured")
      result = instance.call
      project = result.result

      artifact_work_package = WorkPackage.find(project.project_creation_wizard_artifact_work_package_id)
      expected_name = I18n.t("settings.project_initiation_request.name.options.project_creation_wizard")
      expect(artifact_work_package.subject).to eq(expected_name)
    end

    it "if the artifact name is nil, sets the subject to the 'project_creation_wizard' artifact name" do
      project.update(project_creation_wizard_artifact_name: nil)
      result = instance.call
      project = result.result

      artifact_work_package = WorkPackage.find(project.project_creation_wizard_artifact_work_package_id)
      expected_name = I18n.t("settings.project_initiation_request.name.options.project_creation_wizard")
      expect(artifact_work_package.subject).to eq(expected_name)
    end

    it "adds a comment to the artifact work package " \
       "using the project_creation_wizard_work_package_comment setting " \
       "and mentioning the assignee" do
      result = instance.call
      project = result.result

      artifact_work_package = WorkPackage.find(project.project_creation_wizard_artifact_work_package_id)
      expect(artifact_work_package.last_journal.notes).not_to be_empty
      expect(artifact_work_package.last_journal.notes).to include(project.project_creation_wizard_work_package_comment)
      expect(artifact_work_package.last_journal.notes).to include(/<mention[^>]+>@#{assignee_user.name}<\/mention>/)
    end

    context "when artifact storage is internal" do
      it "attaches directly to the work package" do
        project.update(project_creation_wizard_artifact_export_type: "attachment")
        result = instance.call
        project = result.result

        artifact_work_package = WorkPackage.find(project.project_creation_wizard_artifact_work_package_id)
        expect(artifact_work_package.attachments.count).to eq(1)
        attachment = artifact_work_package.attachments.first
        date = Time.zone.today.iso8601
        expect(attachment.content_type).to eq "application/pdf"
        expect(attachment.filename).to match /Important_Project_project_mandate_#{date}_\d+-\d+.pdf/
      end
    end

    context "when artifact storage is project storage" do
      let(:storage) { create(:nextcloud_storage_with_local_connection) }
      let(:project_storage) { create(:project_storage, project:, storage:, project_folder_id: "/project_folder") }

      let(:service_result) { ServiceResult.success(result: nil) }

      before do
        project.update(
          project_creation_wizard_artifact_export_type: "file_link",
          project_creation_wizard_artifact_export_storage: project_storage.id
        )

        allow(Storages::UploadFileService)
          .to receive(:call)
          .and_return(service_result)
      end

      it "calls the nextcloud storage service" do
        result = instance.call
        project = result.result

        expect(result).to be_success
        artifact_work_package = WorkPackage.find(project.project_creation_wizard_artifact_work_package_id)
        expect(artifact_work_package.attachments.count).to eq(0)

        date = Time.zone.today.iso8601
        expect(Storages::UploadFileService)
          .to have_received(:call)
          .with(container: project,
                project_storage:,
                file_path: "project_mandate",
                filename: /Important_Project_project_mandate_#{date}_\d+-\d+.pdf/,
                file_data: instance_of(StringIO))
      end

      context "when service call fails" do
        let(:service_result) { ServiceResult.failure(result: nil) }

        it "rolls back the work package" do
          result = instance.call
          project = result.result

          expect(Storages::UploadFileService)
            .to have_received(:call)

          # The outer service is successful, but an error is added
          expect(result).to be_success
          expect(result.errors[:base]).to include "Failed to store artifact in file storage"

          artifact_work_package = WorkPackage.find(project.project_creation_wizard_artifact_work_package_id)
          expect(artifact_work_package.attachments.count).to eq(0)
        end
      end
    end
  end
end
