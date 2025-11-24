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
      create_params = {
        project:,
        type_id: project.project_creation_wizard_work_package_type_id,
        status_id: project.project_creation_wizard_status_when_submitted_id,
        subject: "Project submission",
        description: "A project submission has been created.",
        attachments: [pdf_attachment]
      }
      creation_call = WorkPackages::CreateService.new(user: User.current).call(create_params)
      if creation_call.success?
        artifact_work_package = creation_call.result
        project.project_creation_wizard_artifact_work_package_id = artifact_work_package.id
        project.save
      else
        service_call.errors.add(:base, I18n.t("projects.wizard.create_artifact_work_package_error"))
        service_call.merge!(creation_call)
      end

      # store_attribute :settings, :project_creation_wizard_work_package_type_id, :integer
      # store_attribute :settings, :project_creation_wizard_status_when_submitted_id, :integer
      # store_attribute :settings, :project_creation_wizard_work_package_comment, :string

      service_call
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
