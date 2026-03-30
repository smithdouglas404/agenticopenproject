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

RSpec.describe Wikis::XWikiProviders::UpdateService do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:wiki_provider) { create(:xwiki_provider) }

  subject(:service) { described_class.new(user: current_user, model: wiki_provider) }

  context "when called by an admin with valid params" do
    let(:current_user) { admin }

    it "updates the provider and returns success" do
      result = service.call(name: "Updated XWiki")
      expect(result).to be_success
      expect(wiki_provider.reload.name).to eq("Updated XWiki")
    end
  end

  context "when called by an admin with invalid params" do
    let(:current_user) { admin }

    it "returns failure with errors" do
      result = service.call(name: "")
      expect(result).to be_failure
      expect(result.result.errors[:name]).to be_present
    end
  end

  context "when called by a non-admin" do
    let(:current_user) { user }

    it "returns failure with authorization error" do
      result = service.call(name: "Updated XWiki")
      expect(result).to be_failure
      expect(result.result.errors[:base]).to include(:error_unauthorized)
    end
  end
end
