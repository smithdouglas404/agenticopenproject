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
  class CreateArtifactWorkPackageContract < ::BaseContract
    validate :validate_project_initiation_request_enabled
    validate :allowed_to_create_work_package
    validate :validate_work_package_type
    validate :validate_work_package_status
    validate :validate_assignee_custom_field

    def project = model

    protected

    def validate_project_initiation_request_enabled
      if !project.project_creation_wizard_enabled?
        errors.add :base, :project_initiation_request_disabled
      end
    end

    def allowed_to_create_work_package
      return if user.allowed_in_project?(:add_work_packages, project)

      errors.add :base, :error_unauthorized
    end

    def validate_work_package_type
      return unless project.project_creation_wizard_enabled?

      if project.project_creation_wizard_work_package_type_id.blank?
        errors.add :project_creation_wizard_work_package_type_id, :blank
      elsif !project.project_creation_wizard_work_package_type_id.in?(project.type_ids)
        errors.add :project_creation_wizard_work_package_type_id, :inclusion
      end
    end

    def validate_work_package_status
      return unless project.project_creation_wizard_enabled?

      if project.project_creation_wizard_status_when_submitted_id.blank?
        errors.add :project_creation_wizard_status_when_submitted_id, :blank
      elsif invalid_status_for_type?
        errors.add :project_creation_wizard_status_when_submitted_id, :inclusion
      end
    end

    def validate_assignee_custom_field
      return unless project.project_creation_wizard_enabled?

      if project.project_creation_wizard_assignee_custom_field_id.blank?
        errors.add :project_creation_wizard_assignee_custom_field_id, :blank
      elsif project.custom_value_for(assignee_custom_field).blank?
        # insufficient permissions to see the custom field value (current user is not a member of the project)
        errors.add assignee_custom_field.attribute_name, :unauthorized
      elsif project.custom_value_for(assignee_custom_field).value.blank?
        errors.add assignee_custom_field.attribute_name, :blank
      end
    end

    def assignee_custom_field
      return @assignee_custom_field if defined?(@assignee_custom_field)

      @assignee_custom_field = ProjectCustomField.find_by(id: project.project_creation_wizard_assignee_custom_field_id)
    end

    def invalid_status_for_type?
      type = Type.find_by(id: project.project_creation_wizard_work_package_type_id)
      return false if type.blank? # no extra error if there is already an error about type being blank

      type.statuses.pluck(:id).exclude?(project.project_creation_wizard_status_when_submitted_id)
    end
  end
end
