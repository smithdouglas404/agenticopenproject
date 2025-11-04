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
require_relative "shared_context"

RSpec.describe "Edit project custom field calculated value",
               :js,
               with_ee: %i[calculated_values weighted_item_lists],
               with_flag: { calculated_value_project_attribute: true } do
  include_context "with seeded project custom fields"

  shared_let(:weighted_item_list_project_custom_field) do
    create(:weighted_item_list_project_custom_field, :skip_validations, name: "Weighted item list field",
                                                                        project_custom_field_section: section_for_select_fields)
  end

  let(:calculated_value) { calculated_from_int_project_custom_field }

  context "with insufficient permissions" do
    it "is not accessible" do
      login_as(non_admin)
      visit edit_admin_settings_project_custom_field_path(calculated_value)

      expect(page).to have_text("You are not authorized to access this page.")
    end
  end

  context "with sufficient permissions" do
    before do
      login_as(admin)
      visit edit_admin_settings_project_custom_field_path(calculated_value)
    end

    it "shows a correct breadcrumb menu" do
      within ".PageHeader-breadcrumbs" do
        expect(page).to have_link("Administration")
        expect(page).to have_link("Projects")
        expect(page).to have_link("Project attributes")
        expect(page).to have_text(calculated_value.name)
      end
    end

    it "shows tab navigation" do
      within_test_selector("project_attribute_detail_header") do
        expect(page).to have_link("Details")
        expect(page).to have_link("Projects")
      end
    end

    context "without calculated_values enterprise feature", with_ee: [] do
      it do
        expect(page)
          .to have_enterprise_banner(:premium)
          .and have_no_field("custom_field_name")
          .and have_no_button("Save")
      end
    end

    context "with calculated_values enterprise feature" do
      it "allows to change basic attributes and the section of the calculated value" do
        expect(page).to have_css(".PageHeader-title", text: calculated_value.name)

        fill_in("custom_field_name", with: "Updated name", fill_options: { clear: :backspace })
        select(section_for_select_fields.name, from: "custom_field_custom_field_section_id")
        find_field(id: "custom_field_formula", type: :hidden).set("1 + 1")

        click_on "Save"

        expect(page).to have_text("Successful update")

        expect(page).to have_css(".PageHeader-title", text: "Updated name")

        expect(calculated_value.reload.name).to eq("Updated name")
        expect(calculated_value.reload.project_custom_field_section).to eq(section_for_select_fields)
        expect(calculated_value.reload.formula_string).to eq("1 + 1")

        within ".PageHeader-breadcrumbs" do
          expect(page).to have_link("Administration")
          expect(page).to have_link("Projects")
          expect(page).to have_link("Project attributes")
          expect(page).to have_text("Updated name")
        end
      end

      it "prevents saving a calculated value with an empty name" do
        original_name = calculated_value.name

        fill_in("custom_field_name", with: "")
        click_on "Save"

        expect(page).to have_text("Name can't be blank")

        expect(page).to have_no_text("Successful update")

        expect(page).to have_css(".PageHeader-title", text: original_name)
        expect(calculated_value.reload.name).to eq(original_name)
      end

      it "prevents saving a calculated value with an empty formula" do
        original_formula = calculated_value.formula_string

        find_field(id: "custom_field_formula", type: :hidden).set("")
        click_on "Save"

        expect(page).to have_text("Formula can't be blank")
        expect(page).to have_no_text("Successful update")

        expect(calculated_value.reload.formula_string).to eq(original_formula)
      end

      it "allows submitting formula by pressing Enter/Return" do
        # ensure multiple spaces are handled without problems
        formula = "2 +  (1   +1)"

        pattern_input = find(:xpath, "//input[@id='custom_field_formula']/parent::div//div[@contenteditable='true']")

        pattern_input.set("#{formula}\n")

        expect(page).to have_text("Successful update")

        expect(calculated_value.reload.formula_string).to eq(formula)
      end

      context "when editing the formula" do
        using CustomFieldFormulaReferencing

        it "allows using the pattern input component" do
          expect(page).to have_css(".PageHeader-title", text: calculated_value.name)

          expect(page).to have_css("input#custom_field_formula[value='#{integer_project_custom_field} * 2']",
                                   visible: :hidden)

          # Suggestions drop down is hidden
          expect(page).to have_no_css(".op-pattern-input--suggestions-dropdown .ActionListItem")

          pattern_input = page.find(".op-pattern-input--text-field")
          pattern_input.click
          pattern_input.send_keys(" + ")
          expect(page).to have_no_css(".op-pattern-input--suggestions-dropdown .ActionListItem")

          # Open suggestion list
          pattern_input.send_keys("/")
          within ".op-pattern-input--suggestions-dropdown" do
            expect(page).to have_css(".ActionListItem", text: float_project_custom_field.name)
            click_on(float_project_custom_field.name)
          end

          # Input divide operator
          pattern_input.send_keys(" / ")
          expect(page).to have_no_css(".op-pattern-input--suggestions-dropdown .ActionListItem")

          # Open suggestion list again
          pattern_input.send_keys("/")
          within ".op-pattern-input--suggestions-dropdown" do
            expect(page).to have_css(".ActionListItem", text: weighted_item_list_project_custom_field.name)
            click_on(weighted_item_list_project_custom_field.name)
          end

          click_on("Save")
          wait_for_network_idle

          new_formula = calculated_value.reload.formula_string
          expect(new_formula)
            .to eq(
              "#{integer_project_custom_field} * 2 + #{float_project_custom_field} / #{weighted_item_list_project_custom_field}"
            )
        end
      end
    end
  end

  context "without the feature flag", with_flag: { calculated_value_project_attribute: false } do
    it "prevents saving a calculated value" do
      expect do
        login_as(admin)
        visit new_admin_settings_project_custom_field_path(field_format: "calculated_value",
                                                           custom_field_section_id: section_for_input_fields.id)
        fill_in("custom_field_name", with: "New calculated value")
        find_field(id: "custom_field_formula", type: :hidden).set("1 + 1")
        click_on "Save"

        expect(page).to have_text("Format is not set to one of the allowed values.")
      end.not_to change(CustomField, :count)
    end
  end
end
