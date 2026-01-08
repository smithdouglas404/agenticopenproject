# frozen_string_literal: true

# -- copyright
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
# ++

RSpec.shared_examples_for "list custom fields" do |type|
  let(:cf_page) { Pages::CustomFields::Index.new }
  let(:user) { create(:admin) }

  current_user { user }

  before do
    cf_page.visit_page type
  end

  it "has the options in the right order" do
    retry_block do
      cf_page.click_to_create_new_custom_field "List"
    end

    cf_page.set_name "Operating System"

    expect(page).to have_text("Allow multi-select")
    check("custom_field_multi_value")

    expect(page).to have_css(".custom-option-row", count: 1)
    within all(".custom-option-row").last do
      find(".custom-option-value input").set "Windows"
      find(".custom-option-default-value input").set true
    end

    retry_block do
      page.find_test_selector("add-custom-option").click

      expect(page).to have_css(".custom-option-row", count: 2)
    end

    within all(".custom-option-row").last do
      find(".custom-option-value input").set "Linux"
    end

    retry_block do
      page.find_test_selector("add-custom-option").click

      expect(page).to have_css(".custom-option-row", count: 3)
    end

    within all(".custom-option-row").last do
      find(".custom-option-value input").set "Solaris"

      click_on "Move to top"
    end

    click_on "Save"

    expect(page).to have_text("Successful creation")

    expect(page).to have_field("custom_field_multi_value", checked: true)

    expect(page).to have_css(".custom-option-row", count: 3)
    expect(page).to have_field("custom_field_custom_options_attributes_0_value", with: "Solaris")
    expect(page).to have_field("custom_field_custom_options_attributes_1_value", with: "Windows")
    expect(page).to have_field("custom_field_custom_options_attributes_2_value", with: "Linux")

    expect(page).to have_field("custom_field_custom_options_attributes_0_default_value", checked: false)
    expect(page).to have_field("custom_field_custom_options_attributes_1_default_value", checked: true)
    expect(page).to have_field("custom_field_custom_options_attributes_2_default_value", checked: false)
  end
end

RSpec.shared_examples_for "hierarchy custom fields on index page" do |type|
  let(:cf_page) { Pages::CustomFields::Index.new }
  let(:user) { create(:admin) }

  current_user { user }

  before do
    cf_page.visit_page type
  end

  context "with an active enterprise token with custom_field_hierarchies feature", with_ee: [:custom_field_hierarchies] do
    it "does not show the enterprise upsell banner and has the 'Hierarchy' option for creation" do
      expect(page).to have_no_text(I18n.t("ee.upsell.custom_field_hierarchies.description"))
      cf_page.expect_having_create_item "Hierarchy"
    end
  end

  context "with an active enterprise token without custom_field_hierarchies feature", with_ee: [:another_feature] do
    it "shows the enterprise upsell banner and lacks the 'Hierarchy' option for creation" do
      expect(page).to have_text(I18n.t("ee.upsell.custom_field_hierarchies.description"))
      cf_page.expect_not_having_create_item "Hierarchy"
    end
  end

  context "with a trial enterprise token", :with_ee_trial, with_ee: [:custom_field_hierarchies] do
    it "shows the enterprise upsell banner and has the 'Hierarchy' option for creation" do
      expect(page).to have_text(I18n.t("ee.upsell.custom_field_hierarchies.description"))
      cf_page.expect_having_create_item "Hierarchy"
    end
  end
end

RSpec.shared_examples_for "expected fields for the custom field's format", :aggregate_failures do |type, format|
  let(:cf_page) { Pages::CustomFields::Index.new }
  let(:user) { create(:admin) }

  current_user { user }

  before do
    cf_page.visit_page type
  end

  def expect_page_to_have(selectors)
    selectors.each do |selector, locators|
      Array(locators).each do |locator|
        expect(page).to send("have_#{selector}".singularize, locator)
      end
    end
  end

  # Form element labels, default English translation in the trailing comment:
  let(:label_min_length) { I18n.t("activerecord.attributes.custom_field.min_length") } # Minimum length
  let(:label_max_length) { I18n.t("activerecord.attributes.custom_field.max_length") } # Maximum length
  let(:label_regexp) { I18n.t("activerecord.attributes.custom_field.regexp") } # Regular expression
  let(:label_multi_value) { I18n.t("activerecord.attributes.custom_field.multi_value") } # Allow multi-select
  # Allow non-open versions
  let(:label_allow_non_open_versions) do
    I18n.t("activerecord.attributes.custom_field.allow_non_open_versions")
  end
  # Possible values
  let(:label_possible_values) do
    I18n.t("activerecord.attributes.custom_field.possible_values")
  end
  let(:label_default_value) { I18n.t("activerecord.attributes.custom_field.default_value") } # Default value
  let(:label_is_required) { I18n.t("activerecord.attributes.custom_field.is_required") } # Required
  let(:label_ee_banner_hierarchy) { I18n.t("ee.upsell.custom_field_hierarchies.description") } # Hierarchy Enterprise banner
  # Spent time SFs don't show "Searchable". Not tested here.
  # Project CFs don't show "For all projects" and "Used as a filter". Not tested here.
  # Content right to left is not shown for Project CFs Long text. Strange. Not tested.

  it "shows the right options for the #{format} custom field type" do
    retry_block do
      cf_page.click_to_create_new_custom_field format
    end

    case format
    when "Text"
      expect_page_to_have(
        fields: [
          label_min_length,
          label_max_length,
          label_regexp,
          label_default_value,
          label_is_required
        ],
        no_labels: [
          label_multi_value,
          label_allow_non_open_versions,
          label_ee_banner_hierarchy
        ],
        no_fieldset: label_possible_values
      )
    when "Long text"
      expect_page_to_have(
        fields: [
          label_min_length,
          label_max_length,
          label_regexp,
          label_is_required
        ],
        rich_text_field: label_default_value,
        no_labels: [
          label_multi_value,
          label_allow_non_open_versions,
          label_ee_banner_hierarchy
        ],
        no_fieldset: label_possible_values
      )
    when "Integer"
      # Integer has min/max_len and regex as well which seems strange.
      expect_page_to_have(
        fields: [
          label_min_length,
          label_max_length,
          label_regexp,
          label_default_value,
          label_is_required
        ],
        no_labels: [
          label_multi_value,
          label_allow_non_open_versions,
          label_ee_banner_hierarchy
        ],
        no_fieldset: label_possible_values
      )
    when "Float"
      # Float has min/max_len and regex as well which seems strange.
      expect_page_to_have(
        fields: [
          label_min_length,
          label_max_length,
          label_regexp,
          label_default_value,
          label_is_required
        ],
        no_labels: [
          label_multi_value,
          label_allow_non_open_versions,
          label_ee_banner_hierarchy
        ],
        no_fieldset: label_possible_values
      )
    when "List"
      expect_page_to_have(
        fields: [
          label_multi_value,
          label_is_required
        ],
        fieldset: label_possible_values,
        no_labels: [
          label_min_length,
          label_max_length,
          label_regexp,
          label_allow_non_open_versions,
          label_default_value,
          label_ee_banner_hierarchy
        ]
      )
    when "Date"
      expect_page_to_have(
        fields: [
          label_is_required
        ],
        no_labels: [
          label_min_length,
          label_max_length,
          label_regexp,
          label_multi_value,
          label_allow_non_open_versions,
          label_default_value,
          label_ee_banner_hierarchy
        ],
        no_fieldset: label_possible_values
      )
    when "Boolean"
      expect_page_to_have(
        fields: [
          label_default_value
        ],
        no_labels: [
          label_min_length,
          label_max_length,
          label_regexp,
          label_multi_value,
          label_is_required,
          label_allow_non_open_versions,
          label_ee_banner_hierarchy
        ],
        no_fieldset: label_possible_values
      )
    when "User"
      expect_page_to_have(
        fields: [
          label_multi_value,
          label_is_required
        ],
        no_labels: [
          label_min_length,
          label_max_length,
          label_regexp,
          label_allow_non_open_versions,
          label_default_value,
          label_ee_banner_hierarchy
        ],
        no_fieldset: label_possible_values
      )
    when "Version"
      expect_page_to_have(
        fields: [
          label_multi_value,
          label_allow_non_open_versions,
          label_is_required
        ],
        no_labels: [
          label_min_length,
          label_max_length,
          label_regexp,
          label_default_value,
          label_ee_banner_hierarchy
        ],
        no_fieldset: label_possible_values
      )
    when "Hierarchy"
      expect_page_to_have(
        fields: [
          label_multi_value,
          label_is_required,
          label_ee_banner_hierarchy
        ],
        no_labels: [
          label_min_length,
          label_max_length,
          label_regexp,
          label_allow_non_open_versions,
          label_default_value
        ],
        no_fieldset: label_possible_values
      )
      expect(page).to have_button("Save", disabled: true)
    when "Link"
      expect_page_to_have(
        fields: [
          label_regexp,
          label_default_value,
          label_is_required
        ],
        no_labels: [
          label_min_length,
          label_max_length,
          label_multi_value,
          label_allow_non_open_versions,
          label_ee_banner_hierarchy
        ],
        no_fieldset: label_possible_values
      )
    else
      fail "fields for #{format} custom field are not defined"
    end
  end
end
