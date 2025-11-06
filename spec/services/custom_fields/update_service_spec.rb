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
require "services/base_services/behaves_like_update_service"

RSpec.describe CustomFields::UpdateService, type: :model do
  it_behaves_like "BaseServices update service"

  describe "#call" do
    let(:user) { build_stubbed(:admin) }
    let(:contract_class) { CustomFields::UpdateContract }
    let(:contract_instance) { instance_double(contract_class, validate: true) }

    let(:instance) do
      described_class.new(user:,
                          model: custom_field,
                          contract_class:)
    end

    subject(:instance_call) { instance.call(attributes) }

    before do
      User.current = user
      allow(contract_class).to receive(:new).with(custom_field, user, options: {}).and_return(contract_instance)
    end

    describe "field_format attribute" do
      context "when trying to change it" do
        let!(:custom_field) { create(:boolean_wp_custom_field) }
        let(:attributes) { { field_format: "text" } }

        it "is ignored" do
          expect(subject).to be_success

          expect(custom_field.reload).to have_attributes(field_format: "bool")
        end
      end
    end

    describe "calculated value custom field",
             with_ee: %i[calculated_values],
             with_flag: { calculated_value_project_attribute: true } do
      using CustomFieldFormulaReferencing

      shared_let(:project1) { create(:project) }
      shared_let(:project2) { create(:project) }
      shared_let(:project3) { create(:project) }
      shared_let(:project4) { create(:project) }
      shared_let(:projects) { [project1, project2, project3, project4] }

      before do
        find_each = allow(Project).to receive(:find_each)

        projects.each do |project|
          find_each.and_yield project
        end
      end

      context "when updating not a calculated value" do
        let!(:custom_field) { create(:integer_project_custom_field) }
        let(:attributes) { { name: "foo" } }

        it "doesn't try to update calculated values" do
          expect(subject).to be_success

          expect(Project).not_to have_received(:find_each)
        end
      end

      context "when not updating formula of calculated value" do
        let!(:custom_field) { create(:calculated_value_project_custom_field) }
        let(:attributes) { { name: "foo" } }

        it "doesn't try to update calculated values" do
          expect(subject).to be_success
          expect(subject.result).to have_attributes(name: "foo")

          expect(Project).not_to have_received(:find_each)
        end
      end

      context "when updating formula of calculated value" do
        let!(:static) { create(:integer_project_custom_field, projects:) }
        let!(:custom_field) do
          create(:calculated_value_project_custom_field,
                 projects: [project1, project2],
                 formula: "1 + 1")
        end
        let!(:custom_field2) do
          create(:calculated_value_project_custom_field,
                 projects: [project1, project3],
                 formula: "#{custom_field} * 10.5")
        end
        let(:attributes) { { formula: "#{static} * 2" } }

        before do
          projects.each.with_index(1) do |project, i|
            # using update_columns to prevent auto enabling for the project
            create(:custom_value, customized: project, custom_field: static).update_columns(value: i)
            create(:custom_value, customized: project, custom_field: custom_field).update_columns(value: 0)
            create(:custom_value, customized: project, custom_field: custom_field2).update_columns(value: 0)
          end
        end

        it "updates calculated values on all objects that have the field enabled" do
          expect(subject).to be_success
          expect(subject.result).to have_attributes(formula_string: "#{static} * 2")

          aggregate_failures do
            expect(project1.custom_value_attributes(all: true))
              .to include(custom_field.id => "2", custom_field2.id => "21.0")
            expect(project2.custom_value_attributes(all: true))
              .to include(custom_field.id => "4", custom_field2.id => "0")
            expect(project3.custom_value_attributes(all: true))
              .to include(custom_field.id => "0", custom_field2.id => "0")
            expect(project4.custom_value_attributes(all: true))
              .to include(custom_field.id => "0", custom_field2.id => "0")
          end
        end

        it "saves the objects when there are changes" do
          projects.each { allow(it).to receive(:save) }

          expect(subject).to be_success
          expect(subject.result).to have_attributes(formula_string: "#{static} * 2")

          expect(project1).to have_received(:save)
          expect(project2).to have_received(:save)
          expect(project3).not_to have_received(:save)
          expect(project4).not_to have_received(:save)
        end
      end

      context "when updating is_required of calculated value to false" do
        let!(:custom_field) { create(:calculated_value_project_custom_field, is_required: true) }
        let(:attributes) { { is_required: false } }

        it "doesn't try to update calculated values" do
          expect(subject).to be_success
          expect(subject.result).to have_attributes(is_required: false)

          expect(Project).not_to have_received(:find_each)
        end
      end

      context "when updating is_required of calculated value to true" do
        let(:attributes) { { is_required: true } }

        context "when custom field has static formula" do
          let!(:custom_field) { create(:calculated_value_project_custom_field, formula: "1 + 1") }

          it "updates calculated values on all objects" do
            expect(subject).to be_success
            expect(subject.result).to have_attributes(is_required: true)

            aggregate_failures do
              projects.each do |project|
                expect(project.custom_value_attributes(all: true)).to include(custom_field.id => "2")
              end
            end
          end

          it "saves all objects" do
            projects.each { allow(it).to receive(:save) }

            expect(subject).to be_success
            expect(subject.result).to have_attributes(is_required: true)

            expect(projects).to all(have_received(:save))
          end
        end

        context "when custom field formula references other fields" do
          let!(:static) { create(:integer_project_custom_field, projects: [project1, project2, project3]) }
          let!(:custom_field) { create(:calculated_value_project_custom_field, formula: "#{static} * 3") }

          before do
            create(:custom_value, customized: project1, custom_field: static, value: 1)
            create(:custom_value, customized: project3, custom_field: static, value: 2)
          end

          it "updates calculated values on all objects that have the static field set" do
            expect(subject).to be_success
            expect(subject.result).to have_attributes(is_required: true)

            aggregate_failures do
              expect(project1.custom_value_attributes(all: true)).to include(custom_field.id => "3")
              expect(project2.custom_value_attributes(all: true)).to include(custom_field.id => nil)
              expect(project3.custom_value_attributes(all: true)).to include(custom_field.id => "6")
              expect(project4.custom_value_attributes(all: true)).to include(custom_field.id => nil)
            end
          end

          it "saves all objects" do
            projects.each { allow(it).to receive(:save) }

            expect(subject).to be_success
            expect(subject.result).to have_attributes(is_required: true)

            expect(projects).to all(have_received(:save))
          end
        end
      end
    end
  end
end
