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

RSpec.describe Queries::Filters::Strategies::Datetime do
  let(:filter) { double("filter", values: [], errors: ActiveModel::Errors.new(double)) }
  let(:strategy) { described_class.new(filter) }

  describe ".supported_operators" do
    it "includes all date-like relative operators" do
      expect(described_class.supported_operators)
        .to include("<t+", ">t+", "t+", "t", "w", ">t-", "<t-", "t-")
    end

    it "includes exact and between datetime operators" do
      expect(described_class.supported_operators).to include("=d", "<>d")
    end

    it "includes not-set operator" do
      expect(described_class.supported_operators).to include("!*")
    end
  end

  describe "operator_map" do
    subject { strategy.send(:operator_map) }

    it "maps =d to OnDateTime (not OnDate)" do
      expect(subject["=d"]).to eq(Queries::Operators::OnDateTime)
    end

    it "maps <>d to BetweenDateTime (not BetweenDate)" do
      expect(subject["<>d"]).to eq(Queries::Operators::BetweenDateTime)
    end
  end
end
