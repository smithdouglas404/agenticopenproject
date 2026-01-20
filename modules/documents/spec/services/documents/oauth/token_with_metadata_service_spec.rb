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

RSpec.describe Documents::OAuth::TokenWithMetadataService,
               with_settings: { collaborative_editing_hocuspocus_secret: "test_secret_for_encryption" } do
  subject(:service_call) { described_class.new(user:).call }

  let(:user) { create(:user) }

  describe "#call" do
    it "returns a successful service result" do
      expect(service_call).to be_success
    end

    it "returns an encrypted token" do
      result = service_call.result

      expect(result[:encrypted_token]).to be_a(String)
      expect(result[:encrypted_token]).not_to be_empty
    end

    it "returns expires_at as ISO8601 timestamp" do
      result = service_call.result

      expect(result[:expires_at]).to be_a(String)
      expect { Time.iso8601(result[:expires_at]) }.not_to raise_error
    end

    it "returns expires_in_seconds matching the token expiry" do
      result = service_call.result

      expect(result[:expires_in_seconds]).to eq(5.minutes.to_i)
    end

    it "creates a new access token" do
      expect { service_call }.to change(Doorkeeper::AccessToken, :count).by(1)
    end
  end

  context "when token generation fails" do
    before do
      allow_any_instance_of(Documents::OAuth::GenerateTokenService) # rubocop:disable RSpec/AnyInstance
        .to receive(:call)
        .and_return(ServiceResult.failure(errors: "Token generation failed"))
    end

    it "returns a failure" do
      expect(service_call).to be_failure
    end
  end

  context "when encryption fails" do
    before do
      allow(Setting)
        .to receive(:collaborative_editing_hocuspocus_secret)
        .and_return(nil)
    end

    it "returns a failure" do
      expect(service_call).to be_failure
    end
  end
end
