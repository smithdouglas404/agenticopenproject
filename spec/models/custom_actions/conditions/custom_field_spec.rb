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

RSpec.describe CustomActions::Conditions::CustomField do
  let(:key) { :"custom_field_#{custom_field.id}" }
  let(:custom_option1) { create(:custom_option, value: "Odin") }
  let(:custom_option2) { create(:custom_option, value: "Dwa") }
  let(:custom_field)   { create(:list_wp_custom_field, custom_options: [custom_option1, custom_option2]) }

  let(:klass) { described_class.all.first }
  let(:instance) do
    allow(WorkPackageCustomField)
      .to receive(:usable_as_custom_action_condition)
      .and_return([custom_field])

    klass.new(custom_option1.id)
  end

  describe "#allowed_values" do
    subject(:method_call) { instance.allowed_values }

    it "is the list of all custom values" do
      expect(method_call)
        .to contain_exactly({ value: custom_option1.id, label: custom_option1.name },
                            { value: custom_option2.id, label: custom_option2.name })
    end
  end

  describe ".custom_field_values" do
    before { allow(described_class).to receive(:custom_field).and_return(custom_field) }

    let(:value1)      { instance_double(CustomFieldValue, custom_field_id: custom_field.id, value: 1) }
    let(:value2)      { instance_double(CustomFieldValue, custom_field_id: custom_field.id, value: 2) }
    let(:other_value) { instance_double(CustomFieldValue, custom_field_id: custom_field.id + 1, value: 999) }

    let(:wp1) do
      instance_double(WorkPackage, custom_field_values: { custom_field.id => value1, 99 => other_value }.values)
    end
    let(:wp2) do
      instance_double(WorkPackage, custom_field_values: { custom_field.id => value2, 11 => value1 }.values)
    end

    it "returns unique string values for matching custom field id" do
      result = described_class.custom_field_values([wp1, wp2])

      expect(result).to match_array(%w[1 2])
    end
  end
end
