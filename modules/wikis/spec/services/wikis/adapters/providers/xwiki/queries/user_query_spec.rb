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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "spec_helper"

RSpec.describe Wikis::Adapters::Providers::XWiki::Queries::UserQuery, :webmock do
  let(:wiki_provider) { build_stubbed(:xwiki_provider, url: "https://xwiki.example.com/xwiki") }
  let(:userinfo_url) { "https://xwiki.example.com/xwiki/oidc/userinfo" }

  subject(:result) { described_class.call(wiki_provider:, access_token: "test-token") }

  context "when the userinfo endpoint returns a valid sub claim" do
    before do
      stub_request(:get, userinfo_url)
        .with(headers: { "Authorization" => "Bearer test-token" })
        .to_return(status: 200, body: { sub: "XWiki.jsmith" }.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns Success with the sub claim" do
      expect(result).to eq(Dry::Monads::Success("XWiki.jsmith"))
    end
  end

  context "when the userinfo endpoint returns an error" do
    before { stub_request(:get, userinfo_url).to_return(status: 401, body: "Unauthorized") }

    it "returns Failure with the status code" do
      expect(result).to be_failure
      expect(result.failure).to include("401")
    end
  end

  context "when the userinfo response is missing the sub claim" do
    before do
      stub_request(:get, userinfo_url)
        .to_return(status: 200, body: { name: "John" }.to_json, headers: { "Content-Type" => "application/json" })
    end

    it "returns Failure" do
      expect(result).to be_failure
      expect(result.failure).to include("sub claim")
    end
  end

  context "when a network error occurs" do
    before { stub_request(:get, userinfo_url).to_raise(StandardError, "connection refused") }

    it "returns Failure" do
      expect(result).to be_failure
      expect(result.failure).to include("connection refused")
    end
  end
end
