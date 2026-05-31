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

RSpec.describe ReleaseCustomFieldSeeder do
  shared_let(:type) { create(:type) }

  it "creates a multi-value, release-scoped version custom field on all types" do
    expect { described_class.new.seed! }.to change(WorkPackageCustomField, :count).by(1)

    custom_field = WorkPackageCustomField.last
    expect(custom_field.field_format).to eq("version")
    expect(custom_field.version_kind).to eq("release")
    expect(custom_field.multi_value).to be(true)
    expect(custom_field.is_for_all).to be(true)
    expect(custom_field.types).to include(type)
  end

  it "is idempotent: does not seed when a release version custom field already exists" do
    described_class.new.seed!

    expect { described_class.new.seed! }.not_to change(WorkPackageCustomField, :count)
  end
end
