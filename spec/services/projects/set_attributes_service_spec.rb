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

RSpec.describe Projects::SetAttributesService, type: :model do
  let(:user) { build_stubbed(:user) }
  let(:contract_class) do
    contract = class_double(Projects::CreateContract)

    allow(contract)
      .to receive(:new)
      .with(project, user, options: {})
      .and_return(contract_instance)

    contract
  end
  let(:contract_instance) do
    instance_double(Projects::CreateContract, validate: contract_valid, errors: contract_errors)
  end
  let(:contract_valid) { true }
  let(:contract_errors) do
    instance_double(ActiveModel::Errors)
  end
  let(:project_valid) { true }
  let(:instance) do
    described_class.new(user:,
                        model: project,
                        contract_class:)
  end
  let(:call_attributes) { {} }
  let(:project) do
    build_stubbed(:project)
  end

  describe "call" do
    before do
      allow(project)
        .to receive(:valid?)
        .and_return(project_valid)

      allow(contract_instance)
        .to receive(:validate)
        .and_return(contract_valid)
    end

    subject { instance.call(call_attributes) }

    it "is successful" do
      expect(subject).to be_success
    end

    it "calls validation" do
      subject

      expect(contract_instance)
        .to have_received(:validate)
    end

    it "sets the attributes" do
      subject

      expect(project.attributes.slice(*project.changed).symbolize_keys)
        .to eql call_attributes
    end

    it "does not persist the project" do
      allow(project)
        .to receive(:save)

      subject

      expect(project)
        .not_to have_received(:save)
    end

    shared_examples "setting status attributes" do
      let(:status_explanation) { "A magic dwells in each beginning." }

      it "sets the project status code" do
        expect(subject.result.status_code)
          .to eq status_code
      end

      it "sets the project status explanation" do
        expect(subject.result.status_explanation)
          .to eq status_explanation
      end
    end

    context "for a new record" do
      let(:project) do
        Project.new
      end

      describe "identifier default value" do
        context "with an identifier provided" do
          let(:call_attributes) do
            {
              identifier: "lorem"
            }
          end

          it "does not alter the identifier" do
            expect(subject.result.identifier)
              .to eql "lorem"
          end
        end
      end

      describe "public default value", with_settings: { default_projects_public: true } do
        context "with a value for is_public provided" do
          let(:call_attributes) do
            {
              public: false
            }
          end

          it "does not alter the public value" do
            expect(subject.result)
              .not_to be_public
          end
        end

        context "with no value for public provided" do
          it "sets uses the default value" do
            expect(subject.result)
              .to be_public
          end
        end
      end

      describe "enabled_module_names default value", with_settings: { default_projects_modules: ["lorem", "ipsum"] } do
        context "with a value for enabled_module_names provided" do
          let(:call_attributes) do
            {
              enabled_module_names: %w(some other)
            }
          end

          it "does not alter the enabled modules" do
            expect(subject.result.enabled_module_names)
              .to match_array %w(some other)
          end
        end

        context "with no value for enabled_module_names provided" do
          it "sets a default enabled modules" do
            expect(subject.result.enabled_module_names)
              .to match_array %w(lorem ipsum)
          end
        end

        context "with the enabled modules being set before" do
          before do
            project.enabled_module_names = %w(some other)
          end

          it "does not alter the enabled modules" do
            expect(subject.result.enabled_module_names)
              .to match_array %w(some other)
          end
        end
      end

      describe "types default value" do
        let(:other_types) do
          [build_stubbed(:type)]
        end
        let(:default_types) do
          [build_stubbed(:type)]
        end

        before do
          allow(Type)
            .to receive(:default)
                  .and_return default_types
        end

        shared_examples "setting custom field defaults" do
          context "with custom fields" do
            let!(:custom_field) { create(:text_wp_custom_field, types:) }
            let!(:custom_field_with_no_type) { create(:text_wp_custom_field) }

            it "activates the type's custom fields" do
              expect(subject.result.work_package_custom_fields)
                .to eq([custom_field])
            end
          end
        end

        context "with a value for types provided" do
          let(:call_attributes) do
            {
              types: other_types
            }
          end

          it "does not alter the types" do
            expect(subject.result.types)
              .to match_array other_types
          end

          include_examples "setting custom field defaults" do
            let(:other_types) { [create(:type)] }
            let(:types) { other_types }
          end
        end

        context "with no value for types provided" do
          it "sets the default types" do
            expect(subject.result.types)
              .to match_array default_types
          end

          include_examples "setting custom field defaults" do
            let(:default_types) { [create(:type)] }
            let(:types) { default_types }
          end
        end

        context "with the types being set before" do
          let(:types) { [build(:type, name: "lorem")] }

          before do
            project.types = types
          end

          it "does not alter the types modules" do
            expect(subject.result.types.map(&:name))
              .to match_array %w(lorem)
          end

          include_examples "setting custom field defaults" do
            let(:types) { [create(:type, name: "lorem")] }
          end
        end
      end

      describe "project status" do
        context "with valid status attributes" do
          let(:status_code) { "on_track" }
          let(:call_attributes) do
            {
              status_code:,
              status_explanation:
            }
          end

          include_examples "setting status attributes"
        end

        context "with an invalid status code provided" do
          let(:status_code) { "wrong" }
          let(:call_attributes) do
            {
              status_code:,
              status_explanation:
            }
          end

          include_examples "setting status attributes"
        end
      end
    end

    context "for an existing project" do
      describe "project status" do
        let(:project) do
          build_stubbed(:project, :with_status)
        end

        context "with a value provided" do
          let(:status_code) { "at_risk" }
          let(:status_explanation) { "Still some magic there." }
          let(:call_attributes) do
            {
              status_code:,
              status_explanation:
            }
          end

          include_examples "setting status attributes"
        end
      end

      describe "calculated custom fields", with_flag: { calculated_value_project_attribute: true } do
        shared_let(:project) { create(:project) }

        before do
          # Both User.current and :select_project_custom_fields for ProjectCustomField.visible
          User.current = user
          mock_permissions_for(user) do |mock|
            mock.allow_in_project(:select_project_custom_fields, project:)
          end
        end

        using CustomFieldFormulaReferencing

        context "when trying to explicitly set values of calculated custom fields" do
          let!(:cf_static) { create(:integer_project_custom_field, projects: [project]) }
          let!(:cf_calculated) do
            create(:calculated_value_project_custom_field,
                   projects: [project], formula: "1 + 1")
          end

          let(:call_attributes) do
            {
              custom_field_values: {
                cf_static.id => 3,
                cf_calculated.id => 4
              }
            }
          end

          before do
            create(:custom_value, customized: project, custom_field: cf_static, value: -5)
            create(:custom_value, customized: project, custom_field: cf_calculated, value: -6)
          end

          it "doesn't allow to assign calculated value" do
            expect(subject.result.custom_value_attributes).to eq(cf_static.id => "3", cf_calculated.id => "-6")
          end
        end

        context "when setting value of field referenced in calculated values" do
          let!(:cf_static) { create(:integer_project_custom_field, projects: [project]) }
          let!(:cf_calculated1) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project],
                   formula: "#{cf_static} * 7")
          end
          let!(:cf_calculated2) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project],
                   formula: "#{cf_calculated1} * 11")
          end

          let(:call_attributes) do
            {
              custom_field_values: {
                cf_static.id => 3
              }
            }
          end

          before do
            create(:custom_value, customized: project, custom_field: cf_static, value: -5)
            create(:custom_value, customized: project, custom_field: cf_calculated1, value: -6)
            create(:custom_value, customized: project, custom_field: cf_calculated2, value: -6)
          end

          it "calculates all values" do
            expect(subject.result.custom_value_attributes).to eq(
              cf_static.id => "3",
              cf_calculated1.id => "21",
              cf_calculated2.id => "231"
            )
          end
        end

        context "when removing value of field referenced in calculated values" do
          let!(:cf_static) { create(:integer_project_custom_field, projects: [project]) }
          let!(:cf_calculated1) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project],
                   formula: "#{cf_static} * 7")
          end
          let!(:cf_calculated2) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project],
                   formula: "#{cf_calculated1} * 11")
          end

          let(:call_attributes) do
            {
              custom_field_values: {
                cf_static.id => nil
              }
            }
          end

          before do
            create(:custom_value, customized: project, custom_field: cf_static, value: -5)
            create(:custom_value, customized: project, custom_field: cf_calculated1, value: -6)
            create(:custom_value, customized: project, custom_field: cf_calculated2, value: -6)
          end

          it "blanks all values" do
            expect(subject.result.custom_value_attributes).to eq(
              cf_static.id => nil,
              cf_calculated1.id => nil,
              cf_calculated2.id => nil
            )
          end
        end

        context "when setting value of only part of fields referenced in calculated values" do
          let!(:cf_a) { create(:integer_project_custom_field, projects: [project]) }
          let!(:cf_b) { create(:integer_project_custom_field, projects: [project]) }
          let!(:cf_c) { create(:integer_project_custom_field, projects: [project]) }
          let!(:cf_calculated1) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project], formula: "#{cf_a} * 7")
          end
          let!(:cf_calculated2) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project], formula: "#{cf_b} * 11")
          end
          let!(:cf_calculated3) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project], formula: "#{cf_c} * 13")
          end

          let(:call_attributes) do
            {
              custom_field_values: {
                cf_a.id => 3,
                cf_b.id => -5
              }
            }
          end

          before do
            create(:custom_value, customized: project, custom_field: cf_a, value: -5)
            create(:custom_value, customized: project, custom_field: cf_b, value: -5)
            create(:custom_value, customized: project, custom_field: cf_c, value: -5)
            create(:custom_value, customized: project, custom_field: cf_calculated1, value: -6)
            create(:custom_value, customized: project, custom_field: cf_calculated2, value: -6)
            create(:custom_value, customized: project, custom_field: cf_calculated3, value: -6)
          end

          it "calculates only values referenced by changed field" do
            expect(subject.result.custom_value_attributes).to eq(
              cf_a.id => "3",
              cf_b.id => "-5",
              cf_c.id => "-5",
              cf_calculated1.id => "21",
              cf_calculated2.id => "-6",
              cf_calculated3.id => "-6"
            )
          end
        end

        context "when intermediate calculated value field is not enabled" do
          let!(:cf_static) { create(:integer_project_custom_field, projects: [project]) }
          let!(:cf_calculated1) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project],
                   formula: "#{cf_static} * 7")
          end
          let!(:cf_calculated2) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   formula: "#{cf_calculated1} * 11")
          end
          let!(:cf_calculated3) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project],
                   formula: "#{cf_calculated2} * 13")
          end

          let(:call_attributes) do
            {
              custom_field_values: {
                cf_static.id => 3
              }
            }
          end

          before do
            create(:custom_value, customized: project, custom_field: cf_static, value: -5)
            create(:custom_value, customized: project, custom_field: cf_calculated1, value: -6)
            create(:custom_value, customized: project, custom_field: cf_calculated2, value: -6)
            create(:custom_value, customized: project, custom_field: cf_calculated3, value: -6)
          end

          it "calculates only accessible values" do
            expect(subject.result.custom_value_attributes).to eq(
              cf_static.id => "3",
              cf_calculated1.id => "21",
              cf_calculated3.id => "-6"
            )

            expect(subject.result.custom_value_attributes(all: true)).to eq(
              cf_static.id => "3",
              cf_calculated1.id => "21",
              cf_calculated2.id => "-6",
              cf_calculated3.id => "-6"
            )
          end
        end

        context "when intermediate calculated value field is for admin only" do
          let!(:cf_static) { create(:integer_project_custom_field, projects: [project]) }
          let!(:cf_calculated1) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project],
                   formula: "#{cf_static} * 7")
          end
          let!(:cf_calculated2) do
            create(:calculated_value_project_custom_field, :skip_validations, :admin_only,
                   projects: [project],
                   formula: "#{cf_calculated1} * 11")
          end
          let!(:cf_calculated3) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project],
                   formula: "#{cf_calculated2} * 13")
          end

          let(:call_attributes) do
            {
              custom_field_values: {
                cf_static.id => 3
              }
            }
          end

          before do
            create(:custom_value, customized: project, custom_field: cf_static, value: -5)
            create(:custom_value, customized: project, custom_field: cf_calculated1, value: -6)
            create(:custom_value, customized: project, custom_field: cf_calculated2, value: -6)
            create(:custom_value, customized: project, custom_field: cf_calculated3, value: -6)
          end

          it "calculates all values" do
            expect(subject.result.custom_value_attributes).to eq(
              cf_static.id => "3",
              cf_calculated1.id => "21",
              cf_calculated2.id => "231",
              cf_calculated3.id => "3003"
            )
          end
        end

        context "when referenced value field is for admin only" do
          let!(:cf_static) { create(:integer_project_custom_field, projects: [project]) }
          let!(:cf_calculated) do
            create(:calculated_value_project_custom_field, :skip_validations,
                   projects: [project],
                   formula: "#{cf_static} * #{cf_referenced}")
          end

          let(:call_attributes) do
            {
              custom_field_values: {
                cf_static.id => 3
              }
            }
          end

          before do
            create(:custom_value, customized: project, custom_field: cf_static, value: 1)
            create(:custom_value, customized: project, custom_field: cf_calculated, value: -6)
          end

          context "when referenced value is static" do
            let!(:cf_referenced) { create(:integer_project_custom_field, :admin_only, projects: [project]) }

            before do
              create(:custom_value, customized: project, custom_field: cf_referenced, value: 2)
            end

            it "calculates using existing value" do
              expect(subject.result.custom_value_attributes).to eq(
                cf_static.id => "3",
                cf_calculated.id => "6"
              )

              expect(subject.result.custom_value_attributes(all: true)).to eq(
                cf_static.id => "3",
                cf_referenced.id => "2",
                cf_calculated.id => "6"
              )
            end
          end

          context "when referenced value is calculated value without references" do
            let!(:cf_referenced) do
              create(:calculated_value_project_custom_field, :skip_validations, :admin_only,
                     projects: [project],
                     formula: "21 * -2")
            end

            before do
              create(:custom_value, customized: project, custom_field: cf_referenced, value: 2)
            end

            it "calculates using existing value" do
              expect(subject.result.custom_value_attributes).to eq(
                cf_static.id => "3",
                cf_calculated.id => "6"
              )

              expect(subject.result.custom_value_attributes(all: true)).to eq(
                cf_static.id => "3",
                cf_referenced.id => "2",
                cf_calculated.id => "6"
              )
            end
          end

          context "when referenced value is calculated value with unchanged reference" do
            let!(:cf_referenced1) { create(:integer_project_custom_field, :admin_only, projects: [project]) }
            let!(:cf_referenced) do
              create(:calculated_value_project_custom_field, :skip_validations, :admin_only,
                     projects: [project],
                     formula: "21 * #{cf_referenced1}")
            end

            before do
              create(:custom_value, customized: project, custom_field: cf_referenced1, value: -2)
              create(:custom_value, customized: project, custom_field: cf_referenced, value: 2)
            end

            it "calculates using existing value" do
              expect(subject.result.custom_value_attributes).to eq(
                cf_static.id => "3",
                cf_calculated.id => "6"
              )

              expect(subject.result.custom_value_attributes(all: true)).to eq(
                cf_static.id => "3",
                cf_referenced1.id => "-2",
                cf_referenced.id => "2",
                cf_calculated.id => "6"
              )
            end
          end
        end
      end
    end
  end
end
