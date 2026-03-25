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

RSpec.describe API::V3::Wikis::ProviderRepresenter do
  include API::V3::Utilities::PathHelper

  describe "rendering" do
    subject(:generated) { representer.to_json }

    let(:representer) { described_class.create(provider, current_user:) }
    let(:current_user) { build_stubbed(:user) }

    shared_examples_for "hides configuration properties from non-admins" do
      context "as an admin user" do
        let(:current_user) { build_stubbed(:admin) }

        it "shows the universalIdentifier" do
          expect(generated).to be_json_eql(provider.universal_identifier.to_json).at_path("universalIdentifier")
        end
      end

      context "as a non-admin user" do
        it "hides the universalIdentifier"do
          expect(generated).not_to have_json_path("universalIdentifier")
        end
      end
    end

    context "for internal wiki provider" do
      let(:provider) { create(:internal_wiki_provider) }

      it "fulfills the documented schema" do
        expect(generated).to match_json_schema.from_docs("wiki_provider_read_model")
      end

      it_behaves_like "hides configuration properties from non-admins"
    end

    context "for XWiki provider" do
      let(:provider) { create(:xwiki_provider) }

      it "fulfills the documented schema" do
        expect(generated).to match_json_schema.from_docs("wiki_provider_read_model")
      end

      it_behaves_like "hides configuration properties from non-admins"
    end
  end
end
