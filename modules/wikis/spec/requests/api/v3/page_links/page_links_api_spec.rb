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

RSpec.describe "API v3 wiki page links resource" do
  include API::V3::Utilities::PathHelper

  let(:work_package) { create(:work_package) }
  let(:internal_wiki) { create(:internal_wiki_provider) }

  let(:project) { work_package.project }

  let(:user) { create(:user, member_with_permissions: { project => %i(view_work_packages view_wiki_page_links) }) }

  let(:relation_page_links) { create_list(:relation_wiki_page_link, 3, provider: internal_wiki, linkable: work_package) }

  before do
    login_as user
    relation_page_links
  end

  describe "GET /api/v3/work_packages/:id/wiki_page_links" do
    let(:path) { api_v3_paths.work_package_page_links(work_package.id) }

    context "with all preconditions met (happy path)" do
      before { get path }

      it_behaves_like "API V3 collection response", 3, 3, "RelationPageLink", "Collection" do
        let(:elements) { relation_page_links.reverse }
      end
    end

    context "when filtered by provider" do
      let(:filter) { [{ provider: { operator: "=", values: [internal_wiki.id] } }] }

      before do
        create_list(:relation_wiki_page_link, 3, provider: create(:xwiki_provider), linkable: work_package)
        get "#{path}?filters=#{CGI.escape(filter.to_json)}"
      end

      it_behaves_like "API V3 collection response", 3, 3, "RelationPageLink", "Collection" do
        let(:elements) { relation_page_links.reverse }
      end
    end
  end
end
