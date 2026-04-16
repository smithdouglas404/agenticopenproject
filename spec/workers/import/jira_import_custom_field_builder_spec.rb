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

# Unit tests for Import::JiraImportCustomFieldBuilder covering every field-type
# mapping implemented in this branch.
RSpec.describe Import::JiraImportCustomFieldBuilder do
  # Helper - build a minimal jira_field double with the given schema hash.
  def jira_field_for(name:, schema:, context_groups: nil)
    payload = { "name" => name, "schema" => schema }
    payload["contextGroups"] = context_groups if context_groups
    instance_double(Import::JiraField, payload:)
  end

  let(:custom_field) { instance_double(WorkPackageCustomField) }

  # =========================================================================
  # #format
  # =========================================================================
  describe "#format" do
    subject(:format) { described_class.new(jira_field).format }

    context "with a plain text field (textfield)" do
      # customfield_10255 "CF String"
      let(:jira_field) do
        jira_field_for(name: "CF String",
                       schema: { "type" => "string",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:textfield",
                                 "customId" => 10255 })
      end

      it { is_expected.to eq("string") }
    end

    context "with a textarea field (textarea)" do
      # customfield_10275 "CF text (plain)"
      let(:jira_field) do
        jira_field_for(name: "CF text (plain)",
                       schema: { "type" => "string",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:textarea",
                                 "customId" => 10275 })
      end

      it { is_expected.to eq("text") }
    end

    context "with a number field (float)" do
      # customfield_10254 "CF Number"
      let(:jira_field) do
        jira_field_for(name: "CF Number",
                       schema: { "type" => "number",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:float",
                                 "customId" => 10254 })
      end

      it { is_expected.to eq("float") }
    end

    context "with a date field (datepicker)" do
      # customfield_10261 "CF Date"
      let(:jira_field) do
        jira_field_for(name: "CF Date",
                       schema: { "type" => "date",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:datepicker",
                                 "customId" => 10261 })
      end

      it { is_expected.to eq("date") }
    end

    context "with a datetime field (data loss!)" do
      # customfield_10262 "CF Datetime"
      let(:jira_field) do
        jira_field_for(name: "CF Datetime",
                       schema: { "type" => "datetime",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:datetime",
                                 "customId" => 10262 })
      end

      it { is_expected.to eq("date") }
    end

    context "with a URL field (url)" do
      # customfield_10257 "CF URL"
      let(:jira_field) do
        jira_field_for(name: "CF URL",
                       schema: { "type" => "string",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:url",
                                 "customId" => 10257 })
      end

      it { is_expected.to eq("link") }
    end

    context "with a single-user field (userpicker)" do
      # customfield_10258 "CF User"
      let(:jira_field) do
        jira_field_for(name: "CF User",
                       schema: { "type" => "string",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:userpicker",
                                 "customId" => 10258 })
      end

      it { is_expected.to eq("user") }
    end

    context "with a multi-user field (multiuserpicker)" do
      # customfield_10259 "CF Users"
      let(:jira_field) do
        jira_field_for(name: "CF Users",
                       schema: { "type" => "array",
                                 "items" => "user",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multiuserpicker",
                                 "customId" => 10259 })
      end

      it { is_expected.to eq("user") }
    end

    context "with a single-select field (select)" do
      # customfield_10264 "CF List"
      let(:jira_field) do
        jira_field_for(name: "CF List",
                       schema: { "type" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:select",
                                 "customId" => 10264 })
      end

      it { is_expected.to eq("list") }
    end

    context "with a multi-select field (multiselect)" do
      # customfield_10265 "CF Multi-List"
      let(:jira_field) do
        jira_field_for(name: "CF Multi-List",
                       schema: { "type" => "array",
                                 "items" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multiselect",
                                 "customId" => 10265 })
      end

      it { is_expected.to eq("list") }
    end

    context "with a multicheckboxes field WITHOUT option_value" do
      # customfield_10260 "CF Booleans"
      # Without option_value the builder falls through to the schema mapping (list).
      let(:jira_field) do
        jira_field_for(name: "CF Booleans",
                       schema: { "type" => "array",
                                 "items" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multicheckboxes",
                                 "customId" => 10260 })
      end

      it "returns 'list' (schema-based fallback, not bool)" do
        expect(subject).to eq("list")
      end
    end

    context "with a multicheckboxes field WITH option_value" do
      let(:jira_field) do
        jira_field_for(name: "CF Booleans",
                       schema: { "type" => "array",
                                 "items" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multicheckboxes",
                                 "customId" => 10260 })
      end

      it "returns 'bool'" do
        builder = described_class.new(jira_field, option_value: "Check 1")
        expect(builder.format).to eq("bool")
      end
    end

    context "with an unknown/any-type field (e.g. Epic Link)" do
      # customfield_10100 "Epic Link"
      let(:jira_field) do
        jira_field_for(name: "Epic Link",
                       schema: { "type" => "any",
                                 "custom" => "com.pyxis.greenhopper.jira:gh-epic-link",
                                 "customId" => 10100 })
      end

      it { is_expected.to eq("string") }
    end

    context "with an array field whose items type is not mapped (e.g. issuelinks)" do
      # customfield_10270 "CF Multiple Issues"
      let(:jira_field) do
        jira_field_for(name: "CF Multiple Issues",
                       schema: { "type" => "array",
                                 "items" => "issuelinks",
                                 "custom" => "com.onresolve.jira.groovy.groovyrunner:multiple-issue-picker-cf",
                                 "customId" => 10270 })
      end

      it "falls back to 'string'" do
        expect(subject).to eq("string")
      end
    end
  end

  # =========================================================================
  # #custom_field_settings - name and format pair
  # =========================================================================
  describe "#custom_field_settings" do
    let(:context_group) do
      {
        "projects" => ["ZB"],
        "issuetypes" => ["10002"],
        "allowedValues" => [
          { "value" => "Cat" }, { "value" => "Dog" }
        ]
      }
    end

    context "with a non-list field (no context_group)" do
      let(:jira_field) do
        jira_field_for(name: "CF String",
                       schema: { "type" => "string",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:textfield" })
      end

      it "uses the field name as-is" do
        name, fmt = described_class.new(jira_field).custom_field_settings
        expect(name).to eq("CF String")
        expect(fmt).to eq("string")
      end
    end

    context "with a list field and a context_group with projects" do
      let(:jira_field) do
        jira_field_for(name: "CF List",
                       schema: { "type" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:select" })
      end

      it "appends the project keys to the name" do
        name, = described_class.new(jira_field, context_group:).custom_field_settings
        expect(name).to eq("CF List (ZB)")
      end
    end

    context "with a multicheckboxes field and option_value" do
      let(:jira_field) do
        jira_field_for(name: "CF Booleans",
                       schema: { "type" => "array",
                                 "items" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multicheckboxes" })
      end

      it "produces 'FieldName - OptionValue' without project key suffix" do
        name, fmt = described_class.new(jira_field, context_group:, option_value: "Check 1").custom_field_settings
        expect(name).to eq("CF Booleans - Check 1")
        expect(fmt).to eq("bool")
        expect(name).not_to include("ZB")
      end
    end
  end

  # =========================================================================
  # #custom_field_parameters
  # =========================================================================
  describe "#custom_field_parameters" do
    context "with a list field that has allowedValues in the context group" do
      let(:context_group) do
        {
          "projects" => ["DYX"],
          "issuetypes" => ["10100"],
          "allowedValues" => [
            { "id" => "10141", "value" => "Cat" },
            { "id" => "10142", "value" => "Dog" }
          ]
        }
      end
      let(:jira_field) do
        jira_field_for(name: "CF List",
                       schema: { "type" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:select" })
      end

      subject(:params) { described_class.new(jira_field, context_group:).custom_field_parameters }

      it "is not multi_value for a single-select field" do
        expect(params[:multi_value]).to be false
      end

      it "includes the option values as possible_values" do
        expect(params[:possible_values]).to eq(%w[Cat Dog])
      end
    end

    context "with a multi-select list field" do
      let(:context_group) do
        {
          "projects" => ["DYX"],
          "issuetypes" => ["10100"],
          "allowedValues" => [
            { "id" => "10145", "value" => "Mouse" },
            { "id" => "10146", "value" => "Turtle" }
          ]
        }
      end
      let(:jira_field) do
        jira_field_for(name: "CF Multi-List",
                       schema: { "type" => "array",
                                 "items" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multiselect" })
      end

      subject(:params) { described_class.new(jira_field, context_group:).custom_field_parameters }

      it { expect(params[:multi_value]).to be true }
      it { expect(params[:possible_values]).to eq(%w[Mouse Turtle]) }
    end

    context "with a single-user field" do
      let(:jira_field) do
        jira_field_for(name: "CF User",
                       schema: { "type" => "string",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:userpicker" })
      end

      it "is not multi_value" do
        params = described_class.new(jira_field).custom_field_parameters
        expect(params[:multi_value]).to be false
      end
    end

    context "with a multi-user field" do
      let(:jira_field) do
        jira_field_for(name: "CF Users",
                       schema: { "type" => "array",
                                 "items" => "user",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multiuserpicker" })
      end

      it "is multi_value" do
        params = described_class.new(jira_field).custom_field_parameters
        expect(params[:multi_value]).to be true
      end
    end

    context "with a multicheckboxes bool field" do
      let(:jira_field) do
        jira_field_for(name: "CF Booleans",
                       schema: { "type" => "array",
                                 "items" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multicheckboxes" })
      end

      it "returns an empty hash (bool CFs need no extra params)" do
        params = described_class.new(jira_field, option_value: "Check 1").custom_field_parameters
        expect(params).to eq({})
      end
    end

    context "with a scalar field (string, float, date, link)" do
      let(:jira_field) do
        jira_field_for(name: "CF Number",
                       schema: { "type" => "number",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:float" })
      end

      it "returns an empty hash" do
        expect(described_class.new(jira_field).custom_field_parameters).to eq({})
      end
    end
  end

  # =========================================================================
  # #convert_value
  # =========================================================================
  describe "#convert_value" do
    context "with a text (textarea) field" do
      let(:jira_field) do
        jira_field_for(name: "CF text (plain)",
                       schema: { "type" => "string",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:textarea" })
      end
      let(:builder) { described_class.new(jira_field) }

      it "converts Jira wiki markup to OP markdown" do
        # Jira: *bold* -> OP: **bold**  (verified via jira_wiki_markup_converter_spec.rb)
        result = builder.convert_value("This is *bold* text.", custom_field)
        expect(result).to eq("This is **bold** text.")
      end

      it "handles nil-like values by converting to empty string" do
        result = builder.convert_value(nil, custom_field)
        expect(result).to eq("")
      end
    end

    context "with a single-select list field" do
      let(:jira_field) do
        jira_field_for(name: "CF List",
                       schema: { "type" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:select" })
      end
      let(:builder) { described_class.new(jira_field) }
      let(:cat_option) { instance_double(CustomOption, id: 1) }

      before do
        allow(custom_field).to receive(:value_of).with("Cat").and_return(cat_option)
      end

      it "looks up the option by value and returns it" do
        result = builder.convert_value({ "id" => "10141", "value" => "Cat" }, custom_field)
        expect(result).to eq(cat_option)
      end

      it "returns nil when the option value is not found in the custom field" do
        allow(custom_field).to receive(:value_of).with("Unknown").and_return(nil)
        result = builder.convert_value({ "value" => "Unknown" }, custom_field)
        expect(result).to be_nil
      end
    end

    context "with a multi-select list field" do
      let(:jira_field) do
        jira_field_for(name: "CF Multi-List",
                       schema: { "type" => "array",
                                 "items" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multiselect" })
      end
      let(:builder) { described_class.new(jira_field) }
      let(:mouse_option) { instance_double(CustomOption, id: 2) }
      let(:turtle_option) { instance_double(CustomOption, id: 3) }

      before do
        allow(custom_field).to receive(:value_of).with("Mouse").and_return(mouse_option)
        allow(custom_field).to receive(:value_of).with("Turtle").and_return(turtle_option)
      end

      it "looks up each option and returns an array" do
        raw = [{ "id" => "10145", "value" => "Mouse" }, { "id" => "10146", "value" => "Turtle" }]
        result = builder.convert_value(raw, custom_field)
        expect(result).to eq([mouse_option, turtle_option])
      end

      it "filters out nil when an option value is not found" do
        allow(custom_field).to receive(:value_of).with("Gone").and_return(nil)
        raw = [{ "value" => "Mouse" }, { "value" => "Gone" }]
        result = builder.convert_value(raw, custom_field)
        expect(result).to eq([mouse_option])
      end
    end

    context "with a multicheckboxes field (bool per option)" do
      let(:jira_field) do
        jira_field_for(name: "CF Booleans",
                       schema: { "type" => "array",
                                 "items" => "option",
                                 "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:multicheckboxes" })
      end

      context "for builder 'Check 1'" do
        let(:builder) { described_class.new(jira_field, option_value: "Check 1") }

        it "returns true when 'Check 1' is in the selected array" do
          raw = [{ "value" => "Check 1" }, { "value" => "Check 2" }]
          expect(builder.convert_value(raw, custom_field)).to be true
        end

        it "returns false when 'Check 1' is not in the selected array" do
          raw = [{ "value" => "Check 2" }]
          expect(builder.convert_value(raw, custom_field)).to be false
        end

        it "returns false for an empty selection" do
          expect(builder.convert_value([], custom_field)).to be false
        end

        it "returns false for a non-array value" do
          expect(builder.convert_value("unexpected", custom_field)).to be false
        end
      end

      context "for builder 'Check 2'" do
        let(:builder) { described_class.new(jira_field, option_value: "Check 2") }

        it "returns true only for its own option" do
          raw = [{ "value" => "Check 2" }]
          expect(builder.convert_value(raw, custom_field)).to be true
        end

        it "returns false when only the other option is selected" do
          raw = [{ "value" => "Check 1" }]
          expect(builder.convert_value(raw, custom_field)).to be false
        end
      end
    end

    context "with scalar passthrough fields (string, float, date, link)" do
      {
        "string" => ["CF String",
                     { "type" => "string",
                       "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:textfield" },
                     "my plain text"],
        "float" => ["CF Number",
                    { "type" => "number",
                      "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:float" },
                    42.5],
        "date" => ["CF Date",
                   { "type" => "date",
                     "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:datepicker" },
                   "2024-01-15"],
        "link" => ["CF URL",
                   { "type" => "string",
                     "custom" => "com.atlassian.jira.plugin.system.customfieldtypes:url" },
                   "https://openproject.org"]
      }.each do |expected_format, (name, schema, raw_value)|
        context "with format '#{expected_format}'" do
          let(:jira_field) { jira_field_for(name:, schema:) }
          let(:builder) { described_class.new(jira_field) }

          it "returns the raw Jira value unchanged" do
            expect(builder.convert_value(raw_value, custom_field)).to eq(raw_value)
          end
        end
      end
    end
  end
end
