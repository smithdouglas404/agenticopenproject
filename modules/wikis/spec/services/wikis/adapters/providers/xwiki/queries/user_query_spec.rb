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
require_module_spec_helper

RSpec.describe Wikis::Adapters::Providers::XWiki::Queries::UserQuery, :webmock do
  let(:wiki_provider) { build_stubbed(:xwiki_provider, url: "https://xwiki.local/") }
  let(:userinfo_url) { "https://xwiki.local/oidc/userinfo" }

  it "is registered" do
    expect(Wikis::Adapters::Registry.resolve("xwiki.queries.user")).to eq(described_class)
  end

  describe ".call" do
    context "when the request succeeds with a sub claim" do
      before do
        stub_request(:get, userinfo_url)
          .to_return(status: 200, body: { sub: "xwiki:XWiki.admin" }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "returns Success with the sub claim" do
        result = described_class.call(wiki_provider:, access_token: "some-token")
        expect(result).to be_success
        expect(result.value!).to eq("xwiki:XWiki.admin")
      end
    end

    context "when the response is missing the sub claim" do
      before do
        stub_request(:get, userinfo_url)
          .to_return(status: 200, body: {}.to_json, headers: { "Content-Type" => "application/json" })
      end

      it "returns Failure mentioning the sub claim" do
        result = described_class.call(wiki_provider:, access_token: "some-token")
        expect(result).to be_failure
        expect(result.failure).to include("sub claim")
      end
    end

    context "when XWiki returns a non-2xx status" do
      before do
        stub_request(:get, userinfo_url).to_return(status: 500, body: "Internal Server Error")
      end

      it "returns Failure with the status code" do
        result = described_class.call(wiki_provider:, access_token: "some-token")
        expect(result).to be_failure
        expect(result.failure).to include("500")
      end
    end

    context "when a network error occurs" do
      before { stub_request(:get, userinfo_url).to_timeout }

      it "returns Failure" do
        result = described_class.call(wiki_provider:, access_token: "some-token")
        expect(result).to be_failure
      end
    end
  end
end
