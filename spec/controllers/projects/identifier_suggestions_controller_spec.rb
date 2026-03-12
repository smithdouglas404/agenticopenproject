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

RSpec.describe Projects::IdentifierSuggestionsController do
  current_user { create(:user) }

  describe "GET #show" do
    context "when the feature flag is off" do
      before { with_flags(semantic_work_package_ids: false) }

      it "returns 404" do
        get :show, params: { name: "My Project" }, format: :json
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the feature flag is on" do
      before { with_flags(semantic_work_package_ids: true) }

      it "returns a suggested identifier derived from the name" do
        get :show, params: { name: "Flight Planning Algorithm" }, format: :json
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["identifier"]).to eq("FPA")
      end

      it "returns a unique suggestion when the base handle is already taken" do
        create(:project, identifier: "FPA")
        get :show, params: { name: "Flight Planning Algorithm" }, format: :json
        expect(response.parsed_body["identifier"]).to eq("FPA2")
      end

      it "requires login" do
        allow(controller).to receive(:logged_in?).and_return(false)
        get :show, params: { name: "Test" }, format: :json
        expect(response).to have_http_status(:unauthorized).or have_http_status(:redirect)
      end
    end
  end
end
