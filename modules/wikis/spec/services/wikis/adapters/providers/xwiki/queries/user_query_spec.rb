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
  let(:rest_url) { "https://xwiki.local/rest/" }

  it "is registered" do
    expect(Wikis::Adapters::Registry.resolve("xwiki.queries.user")).to eq(described_class)
  end

  describe ".call" do
    context "when the request succeeds with xwiki-user header" do
      before do
        stub_request(:get, rest_url)
          .to_return(status: 200, body: "", headers: { "xwiki-user" => "XWiki.admin" })
      end

      it "returns Success with the xwiki-user header value" do
        result = described_class.call(wiki_provider:, access_token: "some-token")
        expect(result).to be_success
        expect(result.value!).to eq("XWiki.admin")
      end
    end

    context "when the token is absent or invalid (XWiki returns 200 without xwiki-user header)" do
      before do
        stub_request(:get, rest_url)
          .to_return(status: 200, body: "", headers: {})
      end

      it "returns Failure mentioning the xwiki-user header" do
        result = described_class.call(wiki_provider:, access_token: "invalid-token")
        expect(result).to be_failure
        expect(result.failure).to include("xwiki-user header")
      end
    end

    context "when XWiki returns a non-2xx status" do
      before do
        stub_request(:get, rest_url).to_return(status: 500, body: "Internal Server Error")
      end

      it "returns Failure with the status code" do
        result = described_class.call(wiki_provider:, access_token: "some-token")
        expect(result).to be_failure
        expect(result.failure).to include("500")
      end
    end

    context "when a network error occurs" do
      before { stub_request(:get, rest_url).to_timeout }

      it "returns Failure" do
        result = described_class.call(wiki_provider:, access_token: "some-token")
        expect(result).to be_failure
      end
    end
  end
end
