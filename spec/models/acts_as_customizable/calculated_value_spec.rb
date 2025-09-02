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

RSpec.describe ActsAsCustomizable::CalculatedValue, with_flag: { calculated_value_project_attribute: true } do
  using CustomFieldFormulaReferencing

  let(:model_class) do
    Class.new do
      include ActsAsCustomizable::CalculatedValue

      def custom_field_values(*) = nil
      attr_writer :custom_field_values
    end
  end

  let(:instance) { model_class.new }

  before do
    allow(instance).to receive(:custom_field_values).with(all: true).and_return(custom_field_values)
    allow(instance).to receive(:custom_field_values=)
  end

  describe "#calculate_custom_fields" do
    context "when calling with empty array" do
      let(:custom_field_values) { [:foo] }

      it "doesn't calculate anything" do
        instance.calculate_custom_fields([])

        expect(instance).not_to have_received(:custom_field_values=)
      end
    end

    context "when calling with non calculated value custom fields" do
      let(:custom_field_values) { [:foo] }

      it "raises an exception when" do
        expect do
          instance.calculate_custom_fields([build(:integer_project_custom_field)])
        end.to raise_error(ArgumentError, "Expected array of calculated value custom fields")
      end

      it "doesn't calculate anything" do
        begin
          instance.calculate_custom_fields([build(:integer_project_custom_field)])
        rescue ArgumentError
          # ignore
        end

        expect(instance).not_to have_received(:custom_field_values=)
      end
    end

    describe "operations" do
      let(:cfs) do
        {
          add: build_stubbed(:calculated_value_project_custom_field, formula: "1 + 2"),
          sub: build_stubbed(:calculated_value_project_custom_field, formula: "2 - 3"),
          mul: build_stubbed(:calculated_value_project_custom_field, formula: "3 * 4"),
          div: build_stubbed(:calculated_value_project_custom_field, formula: "5 / 4"),
          mod: build_stubbed(:calculated_value_project_custom_field, formula: "6 % 5"),
          percent: build_stubbed(:calculated_value_project_custom_field, formula: "6 + 7%"),
          group: build_stubbed(:calculated_value_project_custom_field, formula: "2 * (1 + 2)")
        }
      end

      let(:custom_field_values) { [] }

      it "handles all available operations" do
        instance.calculate_custom_fields(cfs.values)

        expect(instance).to have_received(:custom_field_values=)
          .with(
            cfs[:add].id => 3,
            cfs[:sub].id => -1,
            cfs[:mul].id => 12,
            cfs[:div].id => 5/4r,
            cfs[:mod].id => 1,
            cfs[:percent].id => 607/100r,
            cfs[:group].id => 6
          )
      end
    end

    describe "division by zero" do
      let(:cf_div) { build_stubbed(:calculated_value_project_custom_field, formula: "5 / 0") }
      let(:cf_mod) { build_stubbed(:calculated_value_project_custom_field, formula: "5 % 0") }
      let(:cf_add) { build_stubbed(:calculated_value_project_custom_field, formula: "1 + 2") }

      let(:custom_field_values) { [] }

      it "blanks field with division by zero, but calculates other field" do
        instance.calculate_custom_fields([cf_div, cf_add])

        expect(instance).to have_received(:custom_field_values=)
          .with(
            cf_div.id => nil,
            cf_add.id => 3
          )
      end

      it "blanks field with modulo zero, but calculates other field" do
        instance.calculate_custom_fields([cf_mod, cf_add])

        expect(instance).to have_received(:custom_field_values=)
          .with(
            cf_mod.id => nil,
            cf_add.id => 3
          )
      end
    end

    context "when calling with custom fields referencing constant fields" do
      let(:cf_a) { build_stubbed(:integer_project_custom_field) }
      let(:cf_b) { build_stubbed(:integer_project_custom_field) }

      let(:cf1) { build_stubbed(:calculated_value_project_custom_field, formula: "#{cf_a} + #{cf_b}") }
      let(:cf2) { build_stubbed(:calculated_value_project_custom_field, formula: "#{cf_a} * #{cf_b}") }

      let(:custom_field_values) do
        {
          cf_a => 2,
          cf_b => 3
        }.map { |custom_field, value| build_stubbed(:custom_value, custom_field:, value:) }
      end

      it "calculates values for requested fields" do
        instance.calculate_custom_fields([cf1])
        expect(instance).to have_received(:custom_field_values=).with(cf1.id => 2 + 3).once

        instance.calculate_custom_fields([cf2])
        expect(instance).to have_received(:custom_field_values=).with(cf2.id => 2 * 3).once

        instance.calculate_custom_fields([cf1, cf2])
        expect(instance).to have_received(:custom_field_values=).with(cf1.id => 2 + 3, cf2.id => 2 * 3).once
      end
    end

    context "when calling with custom fields referencing other calculated fields" do
      let(:cf1) { build_stubbed(:calculated_value_project_custom_field, formula: "1 + 1") }
      let(:cf2) { build_stubbed(:calculated_value_project_custom_field, formula: "1 + 2") }
      let(:cf3) { build_stubbed(:calculated_value_project_custom_field, formula: "#{cf1} * #{cf2}") }

      let(:custom_field_values) do
        {
          cf1 => 5,
          cf2 => 7,
          cf3 => 9
        }.map { |custom_field, value| build_stubbed(:custom_value, custom_field:, value:) }
      end

      it "calculates only requested fields in proper order using old values for unrequested fields" do
        instance.calculate_custom_fields([cf1])
        expect(instance).to have_received(:custom_field_values=).with(cf1.id => 2).once

        instance.calculate_custom_fields([cf2])
        expect(instance).to have_received(:custom_field_values=).with(cf2.id => 3).once

        instance.calculate_custom_fields([cf3])
        expect(instance).to have_received(:custom_field_values=).with(cf3.id => 5 * 7).once

        instance.calculate_custom_fields([cf1, cf2])
        expect(instance).to have_received(:custom_field_values=).with(cf1.id => 2, cf2.id => 3).once

        instance.calculate_custom_fields([cf1, cf3])
        expect(instance).to have_received(:custom_field_values=).with(cf1.id => 2, cf3.id => 2 * 7).once

        instance.calculate_custom_fields([cf2, cf3])
        expect(instance).to have_received(:custom_field_values=).with(cf2.id => 3, cf3.id => 5 * 3).once

        instance.calculate_custom_fields([cf1, cf2, cf3])
        expect(instance).to have_received(:custom_field_values=).with(cf1.id => 2, cf2.id => 3, cf3.id => 2 * 3).once
      end
    end

    context "when calling with custom fields referencing missing or unavailable values" do
      let(:cf_missing) { build_stubbed(:integer_project_custom_field) }
      let(:cf_unavailable) { build_stubbed(:integer_project_custom_field) }

      let(:cf_using_missing) { build_stubbed(:calculated_value_project_custom_field, formula: "1 + #{cf_missing}") }
      let(:cf_using_unavailable) { build_stubbed(:calculated_value_project_custom_field, formula: "2 + #{cf_unavailable}") }
      let(:cf_other) { build_stubbed(:calculated_value_project_custom_field, formula: "1 + 2") }

      let(:custom_field_values) do
        {
          cf_missing => nil
        }.map { |custom_field, value| build_stubbed(:custom_value, custom_field:, value:) }
      end

      it "blanks erroneous fields and calculates valid ones" do
        instance.calculate_custom_fields([cf_using_missing, cf_using_unavailable, cf_other])
        expect(instance).to have_received(:custom_field_values=).with(
          cf_using_missing.id => nil,
          cf_using_unavailable.id => nil,
          cf_other.id => 3
        )
      end
    end

    context "when calling with custom fields having circular reference" do
      let(:cf_a) { build_stubbed(:integer_project_custom_field) }
      let(:cf_b) { build_stubbed(:integer_project_custom_field) }
      let(:cf_c) { build_stubbed(:integer_project_custom_field) }
      let(:cf_d) { build_stubbed(:integer_project_custom_field) }

      let(:cf1) { build_stubbed(:calculated_value_project_custom_field) }
      let(:cf2) { build_stubbed(:calculated_value_project_custom_field) }
      let(:cf3) { build_stubbed(:calculated_value_project_custom_field) }
      let(:cf4) { build_stubbed(:calculated_value_project_custom_field) }

      let(:custom_field_values) do
        {
          cf_a => 2,
          cf_b => 3,
          cf_c => 5,
          cf_d => 7,
          cf1 => 11,
          cf2 => 13,
          cf3 => 17,
          cf4 => 19
        }.map { |custom_field, value| build_stubbed(:custom_value, custom_field:, value:) }
      end

      before do
        {
          cf1 => "#{cf_a} * #{cf2}",
          cf2 => "#{cf_b} * #{cf3}",
          cf3 => "#{cf1} * #{cf4}",
          cf4 => "#{cf_c} * #{cf_d}"
        }.each do |cf, formula|
          cf.formula = formula
        end
      end

      it "blanks them when requested to calculate fields that lead to recursion" do
        instance.calculate_custom_fields([cf1, cf2, cf3])

        expect(instance).to have_received(:custom_field_values=)
          .with(cf1.id => nil, cf2.id => nil, cf3.id => nil)
      end

      it "blanks also unrelated fields when requested to calculate fields that lead to recursion" do
        instance.calculate_custom_fields([cf1, cf2, cf3, cf4])

        expect(instance).to have_received(:custom_field_values=)
          .with(cf1.id => nil, cf2.id => nil, cf3.id => nil, cf4.id => nil)
      end

      it "calculates values when there is no recursion in fields requested to calculate (one field)" do
        instance.calculate_custom_fields([cf1])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf1.id => 2 * 13).once

        instance.calculate_custom_fields([cf2])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf2.id => 3 * 17).once

        instance.calculate_custom_fields([cf3])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf3.id => 11 * 19).once

        instance.calculate_custom_fields([cf4])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf4.id => 5 * 7).once
      end

      it "calculates values when there is no recursion in fields requested to calculate (two fields)" do
        instance.calculate_custom_fields([cf1, cf2])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf1.id => 2 * 3 * 17, cf2.id => 3 * 17).once

        instance.calculate_custom_fields([cf1, cf3])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf1.id => 2 * 13, cf3.id => 2 * 13 * 19).once

        instance.calculate_custom_fields([cf1, cf4])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf1.id => 2 * 13, cf4.id => 5 * 7).once

        instance.calculate_custom_fields([cf2, cf3])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf2.id => 3 * 11 * 19, cf3.id => 11 * 19).once

        instance.calculate_custom_fields([cf2, cf4])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf2.id => 3 * 17, cf4.id => 5 * 7).once

        instance.calculate_custom_fields([cf3, cf4])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf3.id => 5 * 7 * 11, cf4.id => 5 * 7).once
      end

      it "calculates values when there is no recursion in fields requested to calculate (three fields)" do
        instance.calculate_custom_fields([cf1, cf2, cf4])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf1.id => 2 * 3 * 17, cf2.id => 3 * 17, cf4.id => 5 * 7).once

        instance.calculate_custom_fields([cf1, cf3, cf4])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf1.id => 2 * 13, cf3.id => 2 * 5 * 7 * 13, cf4.id => 5 * 7).once

        instance.calculate_custom_fields([cf2, cf3, cf4])
        expect(instance).to have_received(:custom_field_values=)
          .with(cf2.id => 3 * 5 * 7 * 11, cf3.id => 5 * 7 * 11, cf4.id => 5 * 7).once
      end
    end
  end
end
