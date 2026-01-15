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

RSpec.describe OAuth::RevokeSessionTokensService do
  subject(:service_call) { described_class.new(user:).call }

  let(:user) { create(:user) }

  after do
    OAuth::SessionBoundApplicationRegistry.reset!
  end

  describe "#call" do
    context "when no applications are registered" do
      it "returns success" do
        result = service_call

        expect(result).to be_success
      end
    end

    context "when a registered application does not exist in the database" do
      before do
        OAuth::SessionBoundApplicationRegistry.register("non_existent_app")
      end

      it "returns success" do
        result = service_call

        expect(result).to be_success
      end
    end

    context "when a registered application exists" do
      let!(:application) do
        create(:oauth_application, uid: "test_session_bound_app")
      end

      before do
        OAuth::SessionBoundApplicationRegistry.register("test_session_bound_app")
      end

      context "with no tokens for the user" do
        it "returns success" do
          result = service_call

          expect(result).to be_success
        end
      end

      context "with tokens for the user" do
        let!(:token1) do
          application.access_tokens.create!(
            resource_owner_id: user.id,
            scopes: "api_v3",
            expires_in: 24.hours.to_i
          )
        end

        let!(:token2) do
          application.access_tokens.create!(
            resource_owner_id: user.id,
            scopes: "api_v3",
            expires_in: 24.hours.to_i
          )
        end

        it "revokes all tokens for the user" do
          expect { service_call }
            .to change { token1.reload.revoked? }.from(false).to(true)
            .and change { token2.reload.revoked? }.from(false).to(true)
        end

        it "returns success" do
          result = service_call

          expect(result).to be_success
        end
      end

      context "with tokens for other users" do
        let(:other_user) { create(:user) }

        let!(:user_token) do
          application.access_tokens.create!(
            resource_owner_id: user.id,
            scopes: "api_v3",
            expires_in: 24.hours.to_i
          )
        end

        let!(:other_user_token) do
          application.access_tokens.create!(
            resource_owner_id: other_user.id,
            scopes: "api_v3",
            expires_in: 24.hours.to_i
          )
        end

        it "only revokes tokens for the specified user" do
          service_call

          expect(user_token.reload).to be_revoked
          expect(other_user_token.reload).not_to be_revoked
        end
      end
    end

    context "with multiple registered applications" do
      let!(:app1) { create(:oauth_application, uid: "app_1") }
      let!(:app2) { create(:oauth_application, uid: "app_2") }
      let!(:unregistered_app) { create(:oauth_application, uid: "unregistered_app") }

      let!(:app1_token) do
        app1.access_tokens.create!(
          resource_owner_id: user.id,
          scopes: "api_v3",
          expires_in: 24.hours.to_i
        )
      end

      let!(:app2_token) do
        app2.access_tokens.create!(
          resource_owner_id: user.id,
          scopes: "api_v3",
          expires_in: 24.hours.to_i
        )
      end

      let!(:unregistered_app_token) do
        unregistered_app.access_tokens.create!(
          resource_owner_id: user.id,
          scopes: "api_v3",
          expires_in: 24.hours.to_i
        )
      end

      before do
        OAuth::SessionBoundApplicationRegistry.register("app_1")
        OAuth::SessionBoundApplicationRegistry.register("app_2")
      end

      it "revokes tokens for all registered applications" do
        service_call

        expect(app1_token.reload).to be_revoked
        expect(app2_token.reload).to be_revoked
      end

      it "does not revoke tokens for unregistered applications" do
        service_call

        expect(unregistered_app_token.reload).not_to be_revoked
      end
    end
  end
end
