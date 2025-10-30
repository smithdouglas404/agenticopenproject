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

RSpec.shared_examples_for "weeks filter" do
  subject(:sql) { described_class.sql_for_field([value], :db_table, :db_field) }

  def quoted_date(date)
    ActiveRecord::Base.connection.quoted_date(date)
  end

  let(:weekday)   { OpenProject::Internationalization::Date.beginning_of_week }
  let(:label_key) { "label_#{described_class.class_name.underscore}" }
  let(:expected) do
    str = []
    str << "db_table.db_field > '#{quoted_date(from)}'" if from.present?
    str << "db_table.db_field <= '#{quoted_date(to)}'" if to.present?

    str.join(" AND ").presence || "1 = 1"
  end

  it "has correct value required flag" do
    expect(described_class.value_required).to eq value_required
  end

  it "has correct label" do
    expect(described_class.label_key).to eq label_key
  end

  it "has correct symbol" do
    expect(described_class.symbol).to eq symbol
  end

  [-5, -1, 0, 2].each do |prime|
    describe "#{prime} weeks" do
      let(:value) { prime }

      it { expect(sql).to eq(expected) }
    end
  end
end
