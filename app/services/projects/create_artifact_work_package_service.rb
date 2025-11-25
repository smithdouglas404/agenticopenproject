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

module Projects
  class CreateArtifactWorkPackageService < ::BaseServices::BaseContracted
    include Contracted
    prepend Projects::Concerns::UpdateDemoData

    def initialize(user:, model:, contract_class: Projects::CreateArtifactWorkPackageContract)
      super(user:, contract_class:)
      self.model = model
    end

    def project = model

    private

    def persist(service_call)
      creation_call = create_artifact_work_package

      creation_call.on_success do
        artifact_work_package = creation_call.result
        project.project_creation_wizard_artifact_work_package_id = artifact_work_package.id
        project.save
      end
      creation_call.on_failure do
        service_call.errors.add(:base, I18n.t("projects.wizard.create_artifact_work_package_error"))
        service_call.merge!(creation_call)
      end

      service_call
    end

    def after_perform(service_call)
      return service_call if store_attachment_locally?

      if project_storage.nil?
        service_call.errors.add(:base, I18n.t("projects.wizard.create_artifact_storage_error"))
        return service_call
      end

      upload_artifact_to_storage(service_call)
    end

    def upload_artifact_to_storage(service_call)
      export = create_pdf_export!

      storage_call = Storages::UploadFileService
        .call(
          container: service_call.result,
          project_storage:,
          file_path: project.project_creation_wizard_artifact_name,
          file_data: StringIO.new(export.content),
          filename: export.title
        )

      storage_call.on_failure do
        service_call.merge!(storage_call, without_success: true)
      end

      service_call
    end

    def project_storage
      return @project_storage if defined?(@project_storage)

      @project_storage = project
        .project_storages
        .find_by(id: project.project_creation_wizard_artifact_export_storage)
    end

    def create_artifact_work_package
      create_params = {
        project:,
        type_id: project.project_creation_wizard_work_package_type_id,
        status_id: project.project_creation_wizard_status_when_submitted_id,
        subject:,
        assigned_to_id:,
        journal_notes:
      }

      create_params[:attachments] = [pdf_attachment] if store_attachment_locally?
      WorkPackages::CreateService.new(user:).call(create_params)
    end

    def journal_notes
      <<~COMMENT
        #{mention_tag(assignee_user)}

        #{project.project_creation_wizard_work_package_comment}
      COMMENT
    end

    def subject
      I18n.t(project.project_creation_wizard_artifact_name,
             default: ::Projects::CreationWizard::DEFAULT_ARTIFACT_NAME_OPTION.to_sym,
             scope: "settings.project_initiation_request.name.options")
    end

    def store_attachment_locally?
      project.project_creation_wizard_artifact_export_type == "attachment"
    end

    def assigned_to_id
      project.custom_value_for(assignee_custom_field).value
    end

    def assignee_user
      User.find(assigned_to_id)
    end

    def assignee_custom_field
      return @assignee_custom_field if defined?(@assignee_custom_field)

      @assignee_custom_field = project.available_custom_fields
                                      .find_by(id: project.project_creation_wizard_assignee_custom_field_id)
    end

    def create_pdf_export!
      Project::PDFExport::ProjectInitiation.new(project).export!
    end

    def pdf_attachment
      export = create_pdf_export!
      file = OpenProject::Files.create_uploaded_file(
        name: export.title,
        content_type: export.mime_type,
        content: export.content,
        binary: true
      )

      Attachment.new(
        container: nil,
        author: user,
        file:
      )
    end

    def mention_tag(user)
      ApplicationController.helpers.content_tag(
        "mention",
        "@#{user.name}",
        class: "mention",
        data: {
          id: user.id,
          type: "user",
          text: "@#{user.name}"
        }
      )
    end
  end
end
