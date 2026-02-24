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
require "services/base_services/behaves_like_create_service"

RSpec.describe UserNonWorkingDays::CreateService do
  it_behaves_like "BaseServices create service" do
    let(:factory) { :user_non_working_day }
  end

  subject(:service_call) { described_class.new(user: current_user).call(params) }

  let(:target_user) { create(:user) }
  let(:date) { Date.tomorrow }
  let(:params) { { user: target_user, date: } }

  context "when the current user has the global manage_working_times permission" do
    let(:current_user) { create(:user, global_permissions: [:manage_working_times]) }

    it "creates the non-working day record successfully" do
      expect(service_call).to be_success
      expect(service_call.result).to be_a(UserNonWorkingDay)
      expect(service_call.result).to be_persisted
      expect(service_call.result.user).to eq(target_user)
      expect(service_call.result.date).to eq(date)
    end
  end

  context "when the current user has manage_own_working_times for their own record" do
    let(:current_user) { create(:user, global_permissions: [:manage_own_working_times]) }
    let(:params) { { user: current_user, date: } }

    it "creates the non-working day record successfully" do
      expect(service_call).to be_success
      expect(service_call.result.user).to eq(current_user)
    end
  end

  context "when the current user has manage_own_working_times but targets another user" do
    let(:current_user) { create(:user, global_permissions: [:manage_own_working_times]) }

    it "is unsuccessful" do
      expect(service_call).to be_failure
    end
  end

  context "when the current user has no relevant permissions" do
    let(:current_user) { create(:user) }

    it "is unsuccessful" do
      expect(service_call).to be_failure
    end
  end

  context "when a system-wide non-working day exists for the same date" do
    let(:current_user) { create(:user, global_permissions: [:manage_working_times]) }

    before { create(:non_working_day, date:) }

    it "is unsuccessful due to the system-wide conflict" do
      expect(service_call).to be_failure
      expect(service_call.errors[:date]).to include(
        I18n.t("activerecord.errors.messages.system_wide_non_working_day_exists")
      )
    end
  end

  context "when no system-wide non-working day exists for the date" do
    let(:current_user) { create(:user, global_permissions: [:manage_working_times]) }

    it "creates the record" do
      expect(service_call).to be_success
    end
  end
end
