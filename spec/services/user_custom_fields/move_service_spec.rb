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

require "rails_helper"

RSpec.describe UserCustomFields::MoveService do
  let(:admin)   { build(:admin) }
  let(:section) { create(:user_custom_field_section) }
  let!(:cf1)    { create(:user_custom_field, user_custom_field_section: section) }
  let!(:cf2)    { create(:user_custom_field, user_custom_field_section: section) }
  let!(:cf3)    { create(:user_custom_field, user_custom_field_section: section) }

  subject(:service) { described_class.new(user: admin, user_custom_field: cf2) }

  it "moves the field higher in attribute_order" do
    result = service.call(move_to: "higher")
    expect(result).to be_success
    expect(section.reload.attribute_order.index(cf2.column_name))
      .to be < section.attribute_order.index(cf1.column_name)
  end

  it "moves the field lower in attribute_order" do
    result = service.call(move_to: "lower")
    expect(result).to be_success
    expect(section.reload.attribute_order.index(cf2.column_name))
      .to be > section.attribute_order.index(cf3.column_name)
  end

  it "moves the field to the top" do
    service.call(move_to: "highest")
    expect(section.reload.attribute_order.first).to eq(cf2.column_name)
  end

  it "moves the field to the bottom" do
    service.call(move_to: "lowest")
    expect(section.reload.attribute_order.last).to eq(cf2.column_name)
  end

  context "when user is not admin" do
    let(:admin) { build(:user) }

    it "returns a failure" do
      result = service.call(move_to: "higher")
      expect(result).not_to be_success
    end
  end
end
