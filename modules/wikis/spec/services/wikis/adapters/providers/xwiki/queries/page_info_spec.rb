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

RSpec.describe Wikis::Adapters::Providers::XWiki::Queries::PageInfo, :webmock do
  it "is registered" do
    expect(Wikis::Adapters::Registry.resolve("xwiki.queries.page_info")).to eq(described_class)
  end

  describe "#call" do
    let(:user) { create(:user) }
    let(:wiki_provider) { create(:xwiki_provider, :with_connected_user, url: "https://xwiki.example.com/", connected_user: user) }
    let(:identifier) { "xwiki:Main.WebHome" }
    let(:page_url) { "https://xwiki.example.com/rest/wikis/xwiki/spaces/Main/pages/WebHome" }
    let(:auth_strategy) { Wikis::Adapters::Input::AuthStrategy.build(key: :bearer_token, user:, provider: wiki_provider).value! }
    let(:input_data) { Wikis::Adapters::Input::PageInfo.build(identifier:).value! }
    let(:query) { described_class.new(model: wiki_provider) }

    subject(:result) { query.call(input_data:, auth_strategy:) }

    context "when the page exists" do
      let(:page_response) do
        { "title" => "Home", "xwikiAbsoluteUrl" => "https://xwiki.example.com/bin/view/Main/" }.to_json
      end

      before do
        stub_request(:get, page_url)
          .with(headers: { "Authorization" => "Bearer user-bearer-token" })
          .to_return(status: 200, body: page_response, headers: { "Content-Type" => "application/json" })
      end

      it "returns Success with title and href" do
        expect(result).to be_success
        expect(result.value!).to have_attributes(
          identifier:,
          title: "Home",
          href: "https://xwiki.example.com/bin/view/Main/"
        )
      end
    end

    context "with a nested space identifier" do
      let(:identifier) { "xwiki:MySpace.SubSpace.PageName" }
      let(:page_url) { "https://xwiki.example.com/rest/wikis/xwiki/spaces/MySpace/spaces/SubSpace/pages/PageName" }
      let(:absolute_url) { "https://xwiki.example.com/bin/view/MySpace/SubSpace/PageName" }

      before do
        stub_request(:get, page_url)
          .to_return(status: 200, body: { "title" => "Nested Page",
                                          "xwikiAbsoluteUrl" => absolute_url }.to_json,
                     headers: { "Content-Type" => "application/json" })
      end

      it "resolves the nested space URL correctly" do
        expect(result).to be_success
        expect(result.value!).to have_attributes(title: "Nested Page")
      end
    end

    context "when the identifier is not a valid XWiki reference" do
      let(:identifier) { "Main.WebHome" }

      it { is_expected.to be_failure.and have_attributes(failure: have_attributes(code: :not_found)) }
    end

    context "when no OAuth token exists for the user" do
      let(:wiki_provider) { create(:xwiki_provider, :with_oauth_client, url: "https://xwiki.example.com/") }

      it { is_expected.to be_failure.and have_attributes(failure: have_attributes(code: :missing_token)) }
    end

    context "when the page is not found" do
      before { stub_request(:get, page_url).to_return(status: 404, body: "") }

      it { is_expected.to be_failure.and have_attributes(failure: have_attributes(code: :not_found)) }
    end

    context "when access is unauthorized" do
      before { stub_request(:get, page_url).to_return(status: 401, body: "") }

      it { is_expected.to be_failure.and have_attributes(failure: have_attributes(code: :unauthorized)) }
    end

    context "when access is forbidden" do
      before { stub_request(:get, page_url).to_return(status: 403, body: "") }

      it { is_expected.to be_failure.and have_attributes(failure: have_attributes(code: :unauthorized)) }
    end

    context "when XWiki returns a non-2xx status" do
      before { stub_request(:get, page_url).to_return(status: 500, body: "Internal Server Error") }

      it { is_expected.to be_failure.and have_attributes(failure: have_attributes(code: :request_failed)) }
    end

    context "when a network error occurs" do
      before { stub_request(:get, page_url).to_timeout }

      it { is_expected.to be_failure.and have_attributes(failure: have_attributes(code: :connection_error)) }
    end

    context "when the response body is not valid JSON" do
      before do
        stub_request(:get, page_url)
          .to_return(status: 200, body: "not json", headers: { "Content-Type" => "application/json" })
      end

      it { is_expected.to be_failure.and have_attributes(failure: have_attributes(code: :invalid_response)) }
    end
  end
end
