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

RSpec.describe UserWorkingHours do
  subject(:working_hours) { build(:user_working_hours) }

  describe "validations" do
    it { is_expected.to be_valid }

    it { is_expected.to validate_presence_of(:valid_from) }

    %i[monday tuesday wednesday thursday friday saturday sunday].each do |day|
      it { is_expected.to validate_presence_of(day) }

      it do
        expect(subject).to validate_numericality_of(day).only_integer
                                                        .is_greater_than_or_equal_to(0)
                                                        .is_less_than_or_equal_to(24 * 60)
      end
    end

    it { is_expected.to validate_presence_of(:availability_factor) }

    it do
      expect(subject).to validate_numericality_of(:availability_factor).only_integer
                                                                       .is_greater_than_or_equal_to(0)
                                                                       .is_less_than_or_equal_to(100)
    end
  end

  describe "hours accessors" do
    subject(:working_hours) { build(:user_working_hours, monday: 480, tuesday: 90, wednesday: 0) }

    %i[monday tuesday wednesday thursday friday saturday sunday].each do |day|
      describe "##{day}_hours" do
        it "returns the minutes value converted to hours" do
          working_hours.public_send("#{day}=", 150)
          expect(working_hours.public_send("#{day}_hours")).to eq(2.5)
        end
      end

      describe "##{day}_hours=" do
        it "stores the hours value converted to minutes" do
          working_hours.public_send("#{day}_hours=", 7.5)
          expect(working_hours.public_send(day)).to eq(450)
        end

        it "rounds fractional minutes" do
          working_hours.public_send("#{day}_hours=", 1.0 / 3)
          expect(working_hours.public_send(day)).to eq(20)
        end
      end
    end

    it "returns 8.0 hours for a full work day of 480 minutes" do
      expect(working_hours.monday_hours).to eq(8.0)
    end

    it "returns 1.5 hours for 90 minutes" do
      expect(working_hours.tuesday_hours).to eq(1.5)
    end

    it "returns 0.0 for a non-working day" do
      expect(working_hours.wednesday_hours).to eq(0.0)
    end
  end

  describe ".valid_for_date" do
    let(:user) { create(:user) }
    let!(:old_hours) { create(:user_working_hours, user:, valid_from: 30.days.ago) }
    let!(:recent_hours) { create(:user_working_hours, user:, valid_from: 10.days.ago) }
    let!(:future_hours) { create(:user_working_hours, user:, valid_from: 10.days.from_now) }

    it "returns the most recent record valid on the given date" do
      expect(described_class.for_user(user).valid_for_date(Date.current)).to eq(recent_hours)
    end

    it "returns the correct record for a past date" do
      expect(described_class.for_user(user).valid_for_date(20.days.ago.to_date)).to eq(old_hours)
    end

    it "returns nil when no record is valid for the given date" do
      expect(described_class.for_user(user).valid_for_date(31.days.ago.to_date)).to be_nil
    end

    it "does not return future records" do
      expect(described_class.for_user(user).valid_for_date(Date.current)).not_to eq(future_hours)
    end
  end

  describe ".current" do
    let(:user) { create(:user) }
    let!(:past_hours) { create(:user_working_hours, user:, valid_from: 10.days.ago) }
    let!(:future_hours) { create(:user_working_hours, user:, valid_from: 10.days.from_now) }

    it "returns the currently valid record" do
      expect(described_class.for_user(user).current).to eq(past_hours)
    end

    it "does not return future records" do
      expect(described_class.for_user(user).current).not_to eq(future_hours)
    end
  end

  describe ".past" do
    let(:user) { create(:user) }
    let!(:older_hours) { create(:user_working_hours, user:, valid_from: 20.days.ago) }
    let!(:recent_past_hours) { create(:user_working_hours, user:, valid_from: 5.days.ago) }
    let!(:future_hours) { create(:user_working_hours, user:, valid_from: 5.days.from_now) }

    it "returns records with valid_from before today" do
      expect(described_class.for_user(user).past).to contain_exactly(older_hours, recent_past_hours)
    end

    it "orders results descending by valid_from" do
      expect(described_class.for_user(user).past).to eq([recent_past_hours, older_hours])
    end

    it "excludes future records" do
      expect(described_class.for_user(user).past).not_to include(future_hours)
    end
  end

  describe ".upcoming" do
    let(:user) { create(:user) }
    let!(:past_hours) { create(:user_working_hours, user:, valid_from: 5.days.ago) }
    let!(:near_future_hours) { create(:user_working_hours, user:, valid_from: 5.days.from_now) }
    let!(:far_future_hours) { create(:user_working_hours, user:, valid_from: 20.days.from_now) }

    it "returns records with valid_from from today onwards" do
      expect(described_class.for_user(user).upcoming).to contain_exactly(near_future_hours, far_future_hours)
    end

    it "orders results ascending by valid_from" do
      expect(described_class.for_user(user).upcoming).to eq([near_future_hours, far_future_hours])
    end

    it "excludes past records" do
      expect(described_class.for_user(user).upcoming).not_to include(past_hours)
    end
  end

  describe ".visible" do
    let(:user) { create(:user) }
    let(:other_user) { create(:user) }
    let!(:user_hours) { create(:user_working_hours, user:) }
    let!(:other_hours) { create(:user_working_hours, user: other_user) }

    context "when the viewer has :manage_working_times permission" do
      let(:viewer) { create(:user, global_permissions: [:manage_working_times]) }

      it "returns all records" do
        expect(described_class.visible(viewer)).to contain_exactly(user_hours, other_hours)
      end
    end

    context "when the viewer has no special permissions" do
      let(:viewer) { create(:user) }
      let!(:viewer_hours) { create(:user_working_hours, user: viewer) }

      it "returns only their own records" do
        expect(described_class.visible(viewer)).to contain_exactly(viewer_hours)
      end

      it "excludes other users' records" do
        expect(described_class.visible(viewer)).not_to include(user_hours, other_hours)
      end
    end
  end
end
