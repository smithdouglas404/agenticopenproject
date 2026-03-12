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

RSpec.describe "GET /projects/identifier_suggestion", type: :rails_request do
  current_user { create(:user) }

  context "when the feature flag is off" do
    before { with_flags(semantic_work_package_ids: false) }

    it "returns 404" do
      get "/projects/identifier_suggestion", params: { name: "My Project" }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  context "when the feature flag is on" do
    before { with_flags(semantic_work_package_ids: true) }

    it "returns a suggested identifier derived from the name" do
      get "/projects/identifier_suggestion", params: { name: "Flight Planning Algorithm" }, as: :json
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["identifier"]).to eq("FPA")
    end

    it "returns 422 when name is blank" do
      get "/projects/identifier_suggestion", params: { name: "" }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "when not logged in" do
      current_user { User.anonymous }

      it "requires login" do
        get "/projects/identifier_suggestion", params: { name: "Test" }, as: :json
        expect(response).to have_http_status(:unauthorized).or have_http_status(:redirect)
      end
    end
  end
end
