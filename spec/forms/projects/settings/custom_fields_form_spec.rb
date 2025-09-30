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
#
require "spec_helper"

RSpec.describe Projects::Settings::CustomFieldsForm, type: :forms do
  let(:string_project_custom_field) { create(:string_project_custom_field, name: "String field", is_required: true) }
  let(:boolean_project_custom_field) { create(:boolean_project_custom_field, name: "Boolean field", is_required: true) }
  let(:text_project_custom_field) { create(:text_project_custom_field, name: "Text field", is_required: true) }
  let(:integer_project_custom_field) { create(:integer_project_custom_field, name: "Integer field", is_required: true) }
  let(:float_project_custom_field) { create(:float_project_custom_field, name: "Float field", is_required: true) }
  let(:date_project_custom_field) { create(:date_project_custom_field, name: "Date field", is_required: true) }
  let(:list_project_custom_field) do
    create(:list_project_custom_field, name: "List field", is_required: true, possible_values: ["eins", "zwei", "drei"])
  end
  let(:multi_list_project_custom_field) do
    create(:list_project_custom_field,
           name: "Multi-list field",
           is_required: true,
           multi_value: true,
           possible_values: ["uno", "due", "tre", "quattro"])
  end
  let(:version_project_custom_field) { create(:version_project_custom_field, name: "Version field", is_required: true) }
  let(:user_project_custom_field) { create(:user_project_custom_field, name: "User field", is_required: true) }
  let(:link_project_custom_field) { create(:link_project_custom_field, name: "Link field", is_required: true) }

  let(:user) { create(:user) }
  let(:version) { create(:version) }

  let(:custom_field_values) do
    {
      "#{string_project_custom_field.id}": "str_val",
      "#{boolean_project_custom_field.id}": true,
      "#{integer_project_custom_field.id}": 43,
      "#{float_project_custom_field.id}": 78.23,
      "#{date_project_custom_field.id}}": Date.civil(2024, 0o3, 20),
      "#{link_project_custom_field.id}}": "https://rubygems.org/",
      "#{list_project_custom_field.id}}": list_project_custom_field.possible_values.first.id,
      "#{multi_list_project_custom_field.id}}": multi_list_project_custom_field.possible_values.last(2).map(&:id),
      "#{version_project_custom_field.id}}": version,
      "#{user_project_custom_field.id}}": user
    }
  end

  let(:model) { create(:project, custom_field_values:) }
  let(:current_user) { build_stubbed(:admin) }

  current_user { build_stubbed(:admin) }

  include_context "with rendered form"

  it "renders HTML input fields", :aggregate_failures do
    expect(page).to have_field "String field", with: "str_val", required: true
    expect(page).to have_checked_field "Boolean field", required: true
    expect(page).to have_field "Integer field", type: :number, with: "43", required: true
    expect(page).to have_field "Float field", type: :number, with: "78.23", required: true
    expect(page).to have_field "Date field", type: :date, with: "2024-03-20", required: true
    expect(page).to have_field "Link field", with: "https://rubygems.org/", required: true
  end

  it "renders list field" do
    expect(page).to have_element :label, text: "List field"

    label_id = page.find(:element, :label, text: "List field")["for"]
    expect(page).to have_element "opce-autocompleter", "data-label-for-id": "\"#{label_id}\"" do |autocompleter|
      expect(autocompleter["data-multiple"]).to be_json_eql(%{false})
      expect(autocompleter["data-items"]).to have_json_size(3)
      expect(autocompleter["data-model"]).to be_json_eql(%{{"name": "eins"}})
    end
  end

  it "renders multi-list field" do
    expect(page).to have_element :label, text: "Multi-list field"

    label_id = page.find(:element, :label, text: "Multi-list field")["for"]
    expect(page).to have_element "opce-autocompleter", "data-label-for-id": "\"#{label_id}\"" do |autocompleter|
      expect(autocompleter["data-multiple"]).to be_json_eql(%{true})
      expect(autocompleter["data-items"]).to have_json_size(4)
      expect(autocompleter["data-model"]).to have_json_size(2)
      expect(autocompleter["data-model"]).to be_json_eql(%{[{"name": "tre"}, {"name": "quattro"}]})
    end
  end

  it "renders version field" do
    expect(page).to have_element :label, text: "Version field"

    label_id = page.find(:element, :label, text: "Version field")["for"]
    expect(page).to have_element "opce-autocompleter", "data-label-for-id": "\"#{label_id}\"" do |autocompleter|
      expect(autocompleter["data-items"]).to have_json_size(0)
      expect(autocompleter["data-model"]).to be_json_eql(%{null})
    end
  end

  it "renders user field" do
    expect(page).to have_element :label, text: "User field"

    label_id = page.find(:element, :label, text: "User field")["for"]
    expect(page).to have_element "opce-user-autocompleter", "data-label-for-id": "\"#{label_id}\"" do |autocompleter|
      expect(autocompleter["data-resource"]).to be_json_eql(%{"principals"})
      expect(autocompleter["data-url"]).to be_json_eql(%{"/api/v3/principals"})
      expect(autocompleter["data-input-value"]).to be_json_eql(%{"#{user.id}"})
    end
  end
end
