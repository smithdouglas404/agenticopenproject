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

RSpec.describe WorkPackageTypes::FormConfigurationSectionsTabController do
  let(:type) { create(:type) }
  let(:user) { create(:admin) }
  let(:temporary_section_key) { described_class::TEMPORARY_SECTION_KEY }

  before do
    allow(User).to receive(:current).and_return(user)
  end

  describe "POST #create", with_ee: %i[edit_attribute_groups] do
    it "renders a temporary attribute section from group_type params" do
      expect do
        post :create, params: { type_id: type.id, group_type: "attribute" }, format: :turbo_stream
      end.not_to change { type.reload.attribute_groups.count }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH #update", with_ee: %i[edit_attribute_groups] do
    it "persists a temporary section when saving it" do
      expect do
        patch :update,
              params: {
                type_id: type.id,
                key: temporary_section_key,
                section: { group_type: "attribute", name: "New Group" }
              },
              format: :turbo_stream
      end.to change { type.reload.attribute_groups.count }.by(1)

      expect(response).to have_http_status(:ok)
      expect(type.reload.attribute_groups.first.key).to eq("New Group")
    end
  end

  describe "PATCH #update (rename)", with_ee: %i[edit_attribute_groups] do
    before do
      type.update_column(:attribute_groups, [
                           ["First section", %w[priority]],
                           ["Second section", %w[assignee]]
                         ])
    end

    context "when renaming to a duplicate name" do
      it "returns an error without the attribute prefix" do
        patch :update,
              params: {
                type_id: type.id,
                key: "First section",
                section: { name: "Second section" }
              },
              format: :turbo_stream

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include(I18n.t("activerecord.errors.models.type.attributes.attribute_groups.duplicate_group"))
        expect(response.body).not_to include("Form configuration")
      end

      it "preserves the entered name in the input field" do
        patch :update,
              params: {
                type_id: type.id,
                key: "First section",
                section: { name: "Second section" }
              },
              format: :turbo_stream

        expect(response.body).to include("Second section")
      end
    end

    context "when renaming to a blank name" do
      it "returns an error" do
        patch :update,
              params: {
                type_id: type.id,
                key: "First section",
                section: { name: "" }
              },
              format: :turbo_stream

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH #update (create with duplicate name)", with_ee: %i[edit_attribute_groups] do
    before do
      type.update_column(:attribute_groups, [["Existing section", %w[priority]]])
    end

    it "returns an error when creating a section with a duplicate name" do
      patch :update,
            params: {
              type_id: type.id,
              key: temporary_section_key,
              section: { group_type: "attribute", name: "Existing section" }
            },
            format: :turbo_stream

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(I18n.t("activerecord.errors.models.type.attributes.attribute_groups.duplicate_group"))
      expect(response.body).not_to include("Form configuration")
    end

    it "preserves the entered name in the input field" do
      patch :update,
            params: {
              type_id: type.id,
              key: temporary_section_key,
              section: { group_type: "attribute", name: "Existing section" }
            },
            format: :turbo_stream

      expect(response.body).to include("Existing section")
    end
  end

  describe "PUT #drop", with_ee: %i[edit_attribute_groups] do
    it "reorders sections using the requested position" do
      type.update_column(:attribute_groups, [
                           [:details, %w[priority]],
                           ["Custom group", %w[version]],
                           [:people, %w[assignee]]
                         ])

      put :drop,
          params: { type_id: type.id, key: "Custom group", position: 1 },
          format: :turbo_stream

      expect(response).to have_http_status(:ok)
      expect(type.reload.attribute_groups.map(&:key)).to eq(["Custom group", :details, :people])
    end
  end
end
