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

RSpec.describe UserNonWorkingDay do
  subject(:non_working_day) { build(:user_non_working_day) }

  describe "validations" do
    it { is_expected.to be_valid }

    it { is_expected.to validate_presence_of(:date) }

    it "validates uniqueness of date scoped to user" do
      existing = create(:user_non_working_day)
      duplicate = build(:user_non_working_day, user: existing.user, date: existing.date)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:date]).to be_present
    end

    it "allows the same date for different users" do
      existing = create(:user_non_working_day)
      other_user = create(:user)
      other = build(:user_non_working_day, user: other_user, date: existing.date)

      expect(other).to be_valid
    end
  end

  describe ".for_year" do
    let(:user) { create(:user) }
    let!(:day_in_year) { create(:user_non_working_day, user:, date: Date.new(2025, 6, 15)) }
    let!(:day_at_start) { create(:user_non_working_day, user:, date: Date.new(2025, 1, 1)) }
    let!(:day_at_end) { create(:user_non_working_day, user:, date: Date.new(2025, 12, 31)) }
    let!(:day_outside_year) { create(:user_non_working_day, user:, date: Date.new(2024, 12, 31)) }

    it "returns records within the given year" do
      expect(described_class.for_user(user).for_year(2025)).to contain_exactly(day_in_year, day_at_start, day_at_end)
    end

    it "excludes records outside the given year" do
      expect(described_class.for_user(user).for_year(2025)).not_to include(day_outside_year)
    end
  end

  describe ".for_user" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let!(:user_day) { create(:user_non_working_day, user:) }
    let!(:other_day) { create(:user_non_working_day, user: other_user) }

    it "returns only records for the given user" do
      expect(described_class.for_user(user)).to contain_exactly(user_day)
    end

    it "excludes records for other users" do
      expect(described_class.for_user(user)).not_to include(other_day)
    end
  end

  describe ".visible" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let!(:user_day) { create(:user_non_working_day, user:) }
    let!(:other_day) { create(:user_non_working_day, user: other_user) }

    context "when the viewer has :manage_working_times permission" do
      let(:viewer) { create(:user, global_permissions: [:manage_working_times]) }

      it "returns all records" do
        expect(described_class.visible(viewer)).to contain_exactly(user_day, other_day)
      end
    end

    context "when the viewer has no special permissions" do
      let(:viewer) { create(:user) }
      let!(:viewer_day) { create(:user_non_working_day, user: viewer) }

      it "returns only their own records" do
        expect(described_class.visible(viewer)).to contain_exactly(viewer_day)
      end

      it "excludes other users' records" do
        expect(described_class.visible(viewer)).not_to include(user_day, other_day)
      end
    end
  end
end
