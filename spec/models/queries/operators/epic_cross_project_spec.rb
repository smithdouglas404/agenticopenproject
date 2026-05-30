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

RSpec.describe Queries::Operators::EpicCrossProject do
  it "uses the cross_project= symbol" do
    expect(described_class.symbol).to eq("cross_project=")
  end

  it "produces the same SQL as the regular Equals operator" do
    sql = described_class.sql_for_field(%w[1 2], "work_packages", :epic_id)

    expect(sql).to eq(Queries::Operators::Equals.sql_for_field(%w[1 2], "work_packages", :epic_id))
  end

  it "is registered in the operator index" do
    expect(Queries::Operators::OPERATORS["cross_project="]).to eq(described_class)
  end
end
