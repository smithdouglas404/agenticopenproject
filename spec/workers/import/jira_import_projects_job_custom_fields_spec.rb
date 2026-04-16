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

# Each example group exercises a specific Jira field type (schema shapes taken from
# The JiraField records are pre-populated with `contextGroups` as if
# Import::JiraFetchCustomFields had already run - this keeps each context focused on
# the import logic rather than the editmeta fetch step.
#
# Fixture: spec/fixtures/import/jira/issue_with_custom_fields.json
#   Contains values for all 8 custom field types in a single issue payload.
RSpec.describe Import::JiraImportProjectsJob, :webmock do
  let(:jira)       { create(:jira) }
  let(:author)     { create(:user) }
  let(:jira_import) do
    create(:jira_import, jira:, author:,
                         projects: [{ "id" => "10242", "key" => "DYX", "name" => "Zombie Engine" }])
  end
  let(:jira_project_payload) { JSON.parse(Rails.root.join("spec/fixtures/import/jira/project.json").read) }
  let(:jira_user_payload)    { JSON.parse(Rails.root.join("spec/fixtures/import/jira/user.json").read) }

  # Issue with values for all custom field types
  # (spec/fixtures/import/jira/issue_with_custom_fields.json)
  let(:issue_payload) do
    JSON.parse(Rails.root.join("spec/fixtures/import/jira/issue_with_custom_fields.json").read)
  end

  let!(:jira_project) do
    create(:jira_project,
           jira:,
           jira_import:,
           jira_project_id: "10242",
           payload: jira_project_payload)
  end
  let!(:default_status) { create(:default_status) }

  # Standard Jira-side entities required for every import run
  let!(:jira_issue_type) do
    create(:jira_issue_type,
           jira:,
           jira_import:,
           jira_issue_type_id: "10100",
           payload: { "id" => "10100", "name" => "Task" })
  end
  let!(:jira_status) do
    create(:jira_status,
           jira:,
           jira_import:,
           jira_status_id: "3",
           payload: { "id" => "3", "name" => "In Progress" })
  end
  let!(:jira_priority) do
    create(:jira_priority,
           jira:,
           jira_import:,
           jira_priority_id: "1",
           payload: { "id" => "1", "name" => "Highest" })
  end
  let!(:jira_user) do
    create(:jira_user,
           jira:,
           jira_import:,
           jira_user_key: "JIRAUSER10000",
           payload: jira_user_payload)
  end
  let!(:op_user) { create(:user, login: "p.balashou", mail: "p.balashou@openproject.com") }
  let!(:jira_user_reference) do
    create(:jira_open_project_reference,
           jira:,
           jira_import:,
           jira_entity_class: "Import::JiraUser",
           jira_entity_id: jira_user.id.to_s,
           op_entity_class: "User",
           op_entity_id: op_user.id.to_s)
  end

  # Context shared across all examples - applies to all projects & issue types
  # (empty arrays mean "applies everywhere").
  let(:global_context) { { "projects" => [], "issuetypes" => [] } }

  # Helper: look up the work package created by the import
  def imported_wp
    WorkPackage.find_by!(subject: "Issue with all custom field types")
  end

  # Helper: look up the OP custom field by name and return its value on the WP
  def cf_value(cf_name)
    cf = WorkPackageCustomField.find_by!(name: cf_name)
    imported_wp.send(cf.attribute_getter)
  end

  describe "string field (com.atlassian.jira.plugin.system.customfieldtypes:textfield)" do
    # customfield_10255 "CF String"
    # Jira value: plain string -> stored as-is.
    let!(:jira_field) do
      create(:jira_field, jira:, jira_import:,
                          jira_field_id: "customfield_10255",
                          payload: {
                            "id" => "customfield_10255",
                            "name" => "CF String",
                            "schema" => {
                              "type" => "string",
                              "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:textfield",
                              "customId" => 10255
                            }
                          })
    end
    let!(:jira_issue) do
      create(:jira_issue, jira:, jira_import:,
                          jira_issue_id: "10200",
                          jira_project_id: jira_project.id,
                          payload: issue_payload)
    end

    before { described_class.new.perform(jira_import.id) }

    it "creates a 'string' custom field" do
      expect(WorkPackageCustomField.find_by!(name: "CF String").field_format).to eq("string")
    end

    it "sets the string value on the work package" do
      expect(cf_value("CF String")).to eq("my plain string value")
    end
  end

  describe "textarea field (com.atlassian.jira.plugin.system.customfieldtypes:textarea)" do
    # customfield_10275 "CF text (plain)"
    # Jira value: Jira wiki markup -> converted to OP markdown.
    let!(:jira_field) do
      create(:jira_field, jira:, jira_import:,
                          jira_field_id: "customfield_10275",
                          payload: {
                            "id" => "customfield_10275",
                            "name" => "CF text (plain)",
                            "schema" => {
                              "type" => "string",
                              "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:textarea",
                              "customId" => 10275
                            }
                          })
    end
    let!(:jira_issue) do
      create(:jira_issue, jira:, jira_import:,
                          jira_issue_id: "10200",
                          jira_project_id: jira_project.id,
                          payload: issue_payload)
    end

    before { described_class.new.perform(jira_import.id) }

    it "creates a 'text' custom field" do
      expect(WorkPackageCustomField.find_by!(name: "CF text (plain)").field_format).to eq("text")
    end

    it "converts Jira wiki markup to OP markdown (bold *x* -> **x**)" do
      # The fixture value is "This is *bold* and _italic_ text."
      # After conversion: "This is **bold** and _italic_ text."
      expect(cf_value("CF text (plain)")).to include("**bold**")
    end
  end

  describe "number field (com.atlassian.jira.plugin.system.customfieldtypes:float)" do
    # customfield_10254 "CF Number"
    # Jira value: numeric -> stored as float.
    let!(:jira_field) do
      create(:jira_field, jira:, jira_import:,
                          jira_field_id: "customfield_10254",
                          payload: {
                            "id" => "customfield_10254",
                            "name" => "CF Number",
                            "schema" => {
                              "type" => "number",
                              "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:float",
                              "customId" => 10254
                            }
                          })
    end
    let!(:jira_issue) do
      create(:jira_issue, jira:, jira_import:,
                          jira_issue_id: "10200",
                          jira_project_id: jira_project.id,
                          payload: issue_payload)
    end

    before { described_class.new.perform(jira_import.id) }

    it "creates a 'float' custom field" do
      expect(WorkPackageCustomField.find_by!(name: "CF Number").field_format).to eq("float")
    end

    it "sets the numeric value on the work package" do
      expect(cf_value("CF Number").to_f).to eq(42.5)
    end
  end

  describe "date field (com.atlassian.jira.plugin.system.customfieldtypes:datepicker)" do
    # customfield_10261 "CF Date"
    # Jira value: ISO date string "2024-06-15".
    let!(:jira_field) do
      create(:jira_field, jira:, jira_import:,
                          jira_field_id: "customfield_10261",
                          payload: {
                            "id" => "customfield_10261",
                            "name" => "CF Date",
                            "schema" => {
                              "type" => "date",
                              "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:datepicker",
                              "customId" => 10261
                            }
                          })
    end
    let!(:jira_issue) do
      create(:jira_issue, jira:, jira_import:,
                          jira_issue_id: "10200",
                          jira_project_id: jira_project.id,
                          payload: issue_payload)
    end

    before { described_class.new.perform(jira_import.id) }

    it "creates a 'date' custom field" do
      expect(WorkPackageCustomField.find_by!(name: "CF Date").field_format).to eq("date")
    end

    it "stores the date value on the work package" do
      expect(cf_value("CF Date")).to eq(Date.parse("2024-06-15"))
    end
  end

  describe "URL field (com.atlassian.jira.plugin.system.customfieldtypes:url)" do
    # customfield_10257 "CF URL"
    # Jira value: URL string -> stored as-is.
    let!(:jira_field) do
      create(:jira_field, jira:, jira_import:,
                          jira_field_id: "customfield_10257",
                          payload: {
                            "id" => "customfield_10257",
                            "name" => "CF URL",
                            "schema" => {
                              "type" => "string",
                              "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:url",
                              "customId" => 10257
                            }
                          })
    end
    let!(:jira_issue) do
      create(:jira_issue, jira:, jira_import:,
                          jira_issue_id: "10200",
                          jira_project_id: jira_project.id,
                          payload: issue_payload)
    end

    before { described_class.new.perform(jira_import.id) }

    it "creates a 'link' custom field" do
      expect(WorkPackageCustomField.find_by!(name: "CF URL").field_format).to eq("link")
    end

    it "stores the URL string on the work package" do
      expect(cf_value("CF URL")).to eq("https://openproject.org")
    end
  end

  describe "single-select list field (com.atlassian.jira.plugin.system.customfieldtypes:select)" do
    # customfield_10264 "CF List"
    # contextGroups populated as JiraFetchCustomFields would after editmeta.
    # Jira value: single option object -> custom field option.
    let!(:jira_field) do
      create(:jira_field, jira:, jira_import:,
                          jira_field_id: "customfield_10264",
                          payload: {
                            "id" => "customfield_10264",
                            "name" => "CF List",
                            "schema" => {
                              "type" => "option",
                              "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:select",
                              "customId" => 10264
                            },
                            "contextGroups" => [
                              global_context.merge(
                                "allowedValues" => [
                                  { "id" => "10141", "value" => "Cat" },
                                  { "id" => "10142", "value" => "Dog" },
                                  { "id" => "10143", "value" => "Green" },
                                  { "id" => "10144", "value" => "Red" }
                                ]
                              )
                            ]
                          })
    end
    let!(:jira_issue) do
      create(:jira_issue, jira:, jira_import:,
                          jira_issue_id: "10200",
                          jira_project_id: jira_project.id,
                          payload: issue_payload)
    end

    before { described_class.new.perform(jira_import.id) }

    it "creates a 'list' custom field with the available options" do
      cf = WorkPackageCustomField.find_by!(name: "CF List")
      expect(cf.field_format).to eq("list")
      expect(cf.custom_options.pluck(:value)).to contain_exactly("Cat", "Dog", "Green", "Red")
    end

    it "is not multi-value" do
      cf = WorkPackageCustomField.find_by!(name: "CF List")
      expect(cf.multi_value).to be false
    end

    it "sets the selected option on the work package" do
      # Fixture selects "Cat"; attribute_getter returns the option string directly
      expect(cf_value("CF List")).to eq("Cat")
    end
  end

  describe "multi-select list field (com.atlassian.jira.plugin.system.customfieldtypes:multiselect)" do
    # customfield_10265 "CF Multi-List"
    # Jira value: array of option objects -> array of custom field options.
    let!(:jira_field) do
      create(:jira_field, jira:, jira_import:,
                          jira_field_id: "customfield_10265",
                          payload: {
                            "id" => "customfield_10265",
                            "name" => "CF Multi-List",
                            "schema" => {
                              "type" => "array",
                              "items" => "option",
                              "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multiselect",
                              "customId" => 10265
                            },
                            "contextGroups" => [
                              global_context.merge(
                                "allowedValues" => [
                                  { "id" => "10145", "value" => "Mouse" },
                                  { "id" => "10146", "value" => "Turtle" }
                                ]
                              )
                            ]
                          })
    end
    let!(:jira_issue) do
      create(:jira_issue, jira:, jira_import:,
                          jira_issue_id: "10200",
                          jira_project_id: jira_project.id,
                          payload: issue_payload)
    end

    before { described_class.new.perform(jira_import.id) }

    it "creates a 'list' custom field that is multi-value" do
      cf = WorkPackageCustomField.find_by!(name: "CF Multi-List")
      expect(cf.field_format).to eq("list")
      expect(cf.multi_value).to be true
    end

    it "sets both selected options on the work package" do
      # attribute_getter returns an array of option strings for multi-value list CFs
      expect(cf_value("CF Multi-List")).to contain_exactly("Mouse", "Turtle")
    end
  end

  describe "multicheckboxes field (com.atlassian.jira.plugin.system.customfieldtypes:multicheckboxes)" do
    # customfield_10260 "CF Booleans"
    # Each checkbox option becomes a separate boolean custom field.
    # Jira value: array of selected options -> true/false per option CF.
    let!(:jira_field) do
      create(:jira_field, jira:, jira_import:,
                          jira_field_id: "customfield_10260",
                          payload: {
                            "id" => "customfield_10260",
                            "name" => "CF Booleans",
                            "schema" => {
                              "type" => "array",
                              "items" => "option",
                              "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multicheckboxes",
                              "customId" => 10260
                            },
                            "contextGroups" => [
                              global_context.merge(
                                "allowedValues" => [
                                  { "id" => "10137",
                                    "self" => "https://jira-software.local/rest/api/2/customFieldOption/10137",
                                    "value" => "Check 1",
                                    "disabled" => false },
                                  { "id" => "10138",
                                    "self" => "https://jira-software.local/rest/api/2/customFieldOption/10138",
                                    "value" => "Check 2",
                                    "disabled" => false }
                                ]
                              )
                            ]
                          })
    end
    let!(:jira_issue) do
      create(:jira_issue, jira:, jira_import:,
                          jira_issue_id: "10200",
                          jira_project_id: jira_project.id,
                          payload: issue_payload)
    end

    before { described_class.new.perform(jira_import.id) }

    it "creates one boolean custom field per checkbox option" do
      cf1 = WorkPackageCustomField.find_by!(name: "CF Booleans - Check 1")
      cf2 = WorkPackageCustomField.find_by!(name: "CF Booleans - Check 2")
      expect(cf1.field_format).to eq("bool")
      expect(cf2.field_format).to eq("bool")
    end

    it "sets the checked option to true on the work package" do
      # The fixture has only 'Check 1' selected
      expect(cf_value("CF Booleans - Check 1")).to be true
    end

    it "sets the unchecked option to false on the work package" do
      expect(cf_value("CF Booleans - Check 2")).to be false
    end

    it "adds both boolean custom fields to the work package type" do
      type = Type.find_by!(name: "Task")
      cf_names = type.custom_fields.pluck(:name)
      expect(cf_names).to include("CF Booleans - Check 1", "CF Booleans - Check 2")
    end
  end

  describe "all custom field types in a single import run" do
    # Registers all 8 field types at once and verifies the correct number of
    # OP custom fields are created (6 simple + 1 list-single + 1 list-multi + 2 bool = 10).
    let!(:jira_fields) do
      [
        { id: "customfield_10255", name: "CF String",
          schema: { "type" => "string",
                    "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:textfield" } },
        { id: "customfield_10275", name: "CF text (plain)",
          schema: { "type" => "string",
                    "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:textarea" } },
        { id: "customfield_10254", name: "CF Number",
          schema: { "type" => "number",
                    "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:float" } },
        { id: "customfield_10261", name: "CF Date",
          schema: { "type" => "date",
                    "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:datepicker" } },
        { id: "customfield_10257", name: "CF URL",
          schema: { "type" => "string",
                    "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:url" } },
        { id: "customfield_10264", name: "CF List",
          schema: { "type" => "option",
                    "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:select" },
          context_groups: [global_context.merge(
            "allowedValues" => [{ "id" => "10141", "value" => "Cat" },
                                { "id" => "10142", "value" => "Dog" }]
          )] },
        { id: "customfield_10265", name: "CF Multi-List",
          schema: { "type" => "array", "items" => "option",
                    "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multiselect" },
          context_groups: [global_context.merge(
            "allowedValues" => [{ "id" => "10145", "value" => "Mouse" },
                                { "id" => "10146", "value" => "Turtle" }]
          )] },
        { id: "customfield_10260", name: "CF Booleans",
          schema: { "type" => "array", "items" => "option",
                    "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multicheckboxes" },
          context_groups: [global_context.merge(
            "allowedValues" => [{ "id" => "10137", "value" => "Check 1" },
                                { "id" => "10138", "value" => "Check 2" }]
          )] }
      ].map do |field_def|
        payload = { "id" => field_def[:id], "name" => field_def[:name], "schema" => field_def[:schema] }
        payload["contextGroups"] = field_def[:context_groups] if field_def[:context_groups]
        create(:jira_field, jira:, jira_import:,
                            jira_field_id: field_def[:id],
                            payload:)
      end
    end
    let!(:jira_issue) do
      create(:jira_issue, jira:, jira_import:,
                          jira_issue_id: "10200",
                          jira_project_id: jira_project.id,
                          payload: issue_payload)
    end

    it "creates the correct number of OpenProject custom fields" do
      # 5 scalar (string, text, float, date, url) + 1 list-single + 1 list-multi + 2 bool (one per checkbox option) = 9
      expect { described_class.new.perform(jira_import.id) }
        .to change(WorkPackageCustomField, :count).by(9)
    end

    context "on after the import" do
      before { described_class.new.perform(jira_import.id) }

      it "creates custom fields with the right formats" do
        expected = {
          "CF String" => "string",
          "CF text (plain)" => "text",
          "CF Number" => "float",
          "CF Date" => "date",
          "CF URL" => "link",
          "CF List" => "list",
          "CF Multi-List" => "list",
          "CF Booleans - Check 1" => "bool",
          "CF Booleans - Check 2" => "bool"
        }
        formats = WorkPackageCustomField.where(name: expected.keys).index_by(&:name).transform_values(&:field_format)
        expect(formats).to eq(expected)
      end

      it "sets all scalar values correctly on the work package" do
        aggregate_failures do
          expect(cf_value("CF String")).to eq("my plain string value")
          expect(cf_value("CF Number").to_f).to eq(42.5)
          expect(cf_value("CF Date")).to eq(Date.parse("2024-06-15"))
          expect(cf_value("CF URL")).to eq("https://openproject.org")
          expect(cf_value("CF text (plain)")).to include("**bold**")
        end
      end

      it "sets the single-select list value correctly" do
        expect(cf_value("CF List")).to eq("Cat")
      end

      it "sets the multi-select list values correctly" do
        expect(cf_value("CF Multi-List")).to contain_exactly("Mouse", "Turtle")
      end

      it "sets multicheckbox boolean values correctly" do
        aggregate_failures do
          expect(cf_value("CF Booleans - Check 1")).to be true
          expect(cf_value("CF Booleans - Check 2")).to be false
        end
      end
    end
  end
end
