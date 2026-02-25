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

RSpec.describe API::V3::UserNonWorkingDays::NonWorkingDaysByUserAPI do
  include API::V3::Utilities::PathHelper

  # Admin users can see all users and manage all working times.
  let(:admin_user) { create(:admin) }
  let(:target_user) { create(:user) }
  let(:headers) { { "CONTENT_TYPE" => "application/json" } }

  let!(:non_working_day_last) { create(:user_non_working_day, user: target_user, date: 1.year.ago) }
  let!(:non_working_day) { create(:user_non_working_day, user: target_user, date: Date.tomorrow) }

  describe "GET /api/v3/users/:user_id/non_working_days" do
    let(:path) { api_v3_paths.user_non_working_days(target_user.id) }

    context "with admin user" do
      current_user { admin_user }

      before { get path }

      it "returns 200 OK" do
        expect(last_response).to have_http_status(200)
      end

      it "returns a collection of non-working days for the current year" do
        expect(last_response.body).to be_json_eql("Collection".to_json).at_path("_type")
        expect(last_response.body).to be_json_eql(1.to_json).at_path("total")
      end
    end

    context "with own user" do
      let(:own_user) { create(:user) }
      let!(:own_day_last_year) { create(:user_non_working_day, user: own_user, date: 1.year.ago) }
      let!(:own_day) { create(:user_non_working_day, user: own_user, date: Date.tomorrow + 1.day) }

      current_user { own_user }

      before { get api_v3_paths.user_non_working_days(own_user.id) }

      it "returns 200 OK" do
        expect(last_response).to have_http_status(200)
      end

      it "returns only own records" do
        expect(last_response.body).to be_json_eql(1.to_json).at_path("total")
      end
    end

    context "with 'me' as the user ID" do
      let(:own_user) { create(:user) }
      let!(:own_day_last_year) { create(:user_non_working_day, user: own_user, date: 1.year.ago) }
      let!(:own_day) { create(:user_non_working_day, user: own_user, date: Date.tomorrow + 1.day) }

      current_user { own_user }

      before { get api_v3_paths.user_non_working_days("me") }

      it "returns 200 OK" do
        expect(last_response).to have_http_status(200)
      end

      it "returns the same records as using the numeric user ID" do
        expect(last_response.body).to be_json_eql(1.to_json).at_path("total")
      end
    end

    context "with regular user (no access to other users)" do
      current_user { create(:user) }

      before { get path }

      it "returns 404 since the user is not visible" do
        # The user API returns 404 when User.visible doesn't include the target user
        expect(last_response).to have_http_status(404)
      end
    end

    context "with year filter" do
      current_user { admin_user }

      it "returns only current year's records by default" do
        get path
        expect(last_response).to have_http_status(200)
        expect(last_response.body).to be_json_eql(1.to_json).at_path("total")
      end

      it "returns the requested year's records when year param is given" do
        get "#{path}?year=#{Date.current.year - 1}"
        expect(last_response).to have_http_status(200)
        expect(last_response.body).to be_json_eql(1.to_json).at_path("total")
        expect(last_response.body).to be_json_eql(1.year.ago.to_date.iso8601.to_json).at_path("_embedded/elements/0/date")
      end
    end

    it_behaves_like "handling anonymous user" do
      let(:path) { api_v3_paths.user_non_working_days(target_user.id) }

      before { get path }
    end
  end

  describe "POST /api/v3/users/:user_id/non_working_days" do
    let(:path) { api_v3_paths.user_non_working_days(target_user.id) }
    let(:new_date) { (Date.tomorrow + 1.week).iso8601 }
    let(:valid_params) { { date: new_date } }

    context "with admin user" do
      current_user { admin_user }

      before { post path, valid_params.to_json, headers }

      it "returns 201 Created" do
        expect(last_response).to have_http_status(201)
      end

      it "creates a non-working day for the target user" do
        parsed = JSON.parse(last_response.body)
        expect(parsed["_type"]).to eq("UserNonWorkingDay")
        expect(parsed["date"]).to eq(new_date)
      end
    end

    context "when a system-wide NonWorkingDay exists for the same date" do
      let!(:system_non_working_day) { create(:non_working_day, date: Date.parse(new_date)) }

      current_user { admin_user }

      before { post path, valid_params.to_json, headers }

      it "returns 422 Unprocessable Entity" do
        expect(last_response).to have_http_status(422)
      end
    end

    context "with 'me' as the user ID with manage_own_working_times permission" do
      let(:own_user) { create(:user, global_permissions: [:manage_own_working_times]) }

      current_user { own_user }

      before { post api_v3_paths.user_non_working_days("me"), valid_params.to_json, headers }

      it "returns 201 Created" do
        expect(last_response).to have_http_status(201)
      end

      it "creates a non-working day for the current user" do
        parsed = JSON.parse(last_response.body)
        expect(parsed["_type"]).to eq("UserNonWorkingDay")
        expect(parsed["date"]).to eq(new_date)
      end
    end

    context "with regular user targeting another user" do
      current_user { create(:user) }

      before { post path, valid_params.to_json, headers }

      it "returns 404 since the target user is not visible" do
        expect(last_response).to have_http_status(404)
      end
    end
  end

  describe "DELETE /api/v3/users/:user_id/non_working_days/:date" do
    let(:path) { api_v3_paths.user_non_working_day(target_user.id, non_working_day.date) }

    context "with admin user" do
      current_user { admin_user }

      before { delete path }

      it "returns 204 No Content" do
        expect(last_response).to have_http_status(204)
      end

      it "deletes the record" do
        expect(UserNonWorkingDay.find_by(id: non_working_day.id)).to be_nil
      end
    end

    context "with 'me' as the user ID with manage_own_working_times permission" do
      let(:own_user) { create(:user, global_permissions: [:manage_own_working_times]) }
      let!(:own_day) { create(:user_non_working_day, user: own_user, date: Date.tomorrow + 2.days) }

      current_user { own_user }

      before { delete api_v3_paths.user_non_working_day("me", own_day.date) }

      it "returns 204 No Content" do
        expect(last_response).to have_http_status(204)
      end

      it "deletes the record" do
        expect(UserNonWorkingDay.find_by(id: own_day.id)).to be_nil
      end
    end

    context "with regular user (no access to other users)" do
      current_user { create(:user) }

      before { delete path }

      it "returns 404 since the target user is not visible" do
        expect(last_response).to have_http_status(404)
      end
    end
  end
end
