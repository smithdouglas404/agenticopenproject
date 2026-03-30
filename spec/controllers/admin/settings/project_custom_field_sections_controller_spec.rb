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

RSpec.describe Admin::Settings::ProjectCustomFieldSectionsController do
  shared_let(:user) { create(:admin) }
  shared_let(:section) { create(:project_custom_field_section) }

  current_user { user }
  render_views

  let(:error_message) { "Something went wrong." }
  let(:service_result) do
    ServiceResult.failure(result: section).tap do |result|
      result.errors.add(:base, error_message)
    end
  end

  describe "DELETE #destroy" do
    it "renders an error flash turbo stream" do
      delete_service = instance_double(ProjectCustomFieldSections::DeleteService, call: service_result)

      allow(ProjectCustomFieldSections::DeleteService)
        .to receive(:new)
        .with(user:, model: section)
        .and_return(delete_service)

      delete :destroy, params: { id: section.id }, format: :turbo_stream

      expect(response).to be_successful
      expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
      expect(response.body).to include(error_message)
    end
  end

  describe "PUT #move" do
    before do
      update_service = instance_double(ProjectCustomFieldSections::UpdateService, call: service_result)

      allow(ProjectCustomFieldSections::UpdateService)
        .to receive(:new)
        .with(user:, model: section)
        .and_return(update_service)
    end

    it "renders an error flash turbo stream" do
      put :move, params: { id: section.id, move_to: "higher" }, format: :turbo_stream

      expect(response).to be_successful
      expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
      expect(response.body).to include(error_message)
    end
  end

  describe "PUT #drop" do
    before do
      update_service = instance_double(ProjectCustomFieldSections::UpdateService, call: service_result)

      allow(ProjectCustomFieldSections::UpdateService)
        .to receive(:new)
        .with(user:, model: section)
        .and_return(update_service)
    end

    it "renders an error flash turbo stream" do
      put :drop, params: { id: section.id, position: "2" }, format: :turbo_stream

      expect(response).to be_successful
      expect(response).to have_turbo_stream action: "flash", target: "op-primer-flash-component"
      expect(response.body).to include(error_message)
    end
  end
end
