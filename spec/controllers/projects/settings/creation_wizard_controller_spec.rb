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

RSpec.describe Projects::Settings::CreationWizardController do
  shared_let(:user) { create(:admin) }
  let(:set_attributes_service) { instance_double(Projects::SetAttributesService, call: service_result) }

  current_user { user }

  describe "GET #show" do
    let(:project) { build_stubbed(:project) }

    before do
      allow(Project)
        .to receive(:find)
              .with(project.identifier)
              .and_return(project)

      allow(Projects::SetAttributesService)
        .to receive(:new)
              .with(
                model: project,
                user:,
                contract_class: Projects::SettingsContract,
                contract_options: { validate_all: true }
              )
              .and_return(set_attributes_service)

      get :show, params: { project_id: project.identifier }
    end

    context "when the service returns a successful validation result" do
      let(:service_result) { ServiceResult.success(result: project) }

      it "renders the show template and assigns the validation result", :aggregate_failures do
        expect(response).to be_successful
        expect(assigns(:validation_result)).to eq(service_result)
      end
    end

    context "when the service returns a failed validation result" do
      let(:service_result) do
        ServiceResult.failure(result: project, errors: project.errors).tap do |result|
          result.errors.add(:project_creation_wizard_work_package_type_id, :blank)
          result.errors.add(:project_creation_wizard_assignee_custom_field_id, :blank)
        end
      end

      it "still renders the show template successfully", :aggregate_failures do
        expect(response).to be_successful
        expect(assigns(:validation_result)).to eq(service_result)
        expect(assigns(:validation_result)).to be_failure
      end
    end
  end
end
