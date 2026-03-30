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

RSpec.describe Wikis::XWikiProviders::CreateService do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }

  subject(:service) { described_class.new(user: current_user) }

  context "when called by an admin with valid params" do
    let(:current_user) { admin }
    let(:params) { { name: "My XWiki", url: "https://xwiki.example.com" } }

    it "creates the provider and returns success" do
      result = service.call(params)
      expect(result).to be_success
      expect(result.result).to be_a(Wikis::XWikiProvider)
      expect(result.result).to be_persisted
      expect(result.result.name).to eq("My XWiki")
      expect(result.result.url).to eq("https://xwiki.example.com")
    end
  end

  context "when called by an admin with invalid params" do
    let(:current_user) { admin }
    let(:params) { { name: "", url: "https://xwiki.example.com" } }

    it "returns failure with errors" do
      result = service.call(params)
      expect(result).to be_failure
      expect(result.result.errors[:name]).to be_present
    end
  end

  context "when called by a non-admin" do
    let(:current_user) { user }
    let(:params) { { name: "My XWiki", url: "https://xwiki.example.com" } }

    it "returns failure with authorization error" do
      result = service.call(params)
      expect(result).to be_failure
      expect(result.result.errors[:base]).to include(:error_unauthorized)
    end
  end
end
