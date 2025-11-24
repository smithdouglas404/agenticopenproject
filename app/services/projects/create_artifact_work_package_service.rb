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

    def create_artifact_work_package
      create_params = {
        project:,
        type_id: project.project_creation_wizard_work_package_type_id,
        status_id: project.project_creation_wizard_status_when_submitted_id,
        subject: "Project submission",
        description: "A project submission has been created.",
        assigned_to_id:,
        attachments: [pdf_attachment]
      }
      WorkPackages::CreateService.new(user:).call(create_params)
    end

    def assigned_to_id
      project.custom_value_for(assignee_custom_field).value
    end

    def assignee_custom_field
      return @assignee_custom_field if defined?(@assignee_custom_field)

      @assignee_custom_field = project.available_custom_fields
                                      .find_by(id: project.project_creation_wizard_assignee_custom_field_id)
    end

    def pdf_attachment
      export = Project::PDFExport::ProjectInitiation.new(project).export!

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
  end
end
