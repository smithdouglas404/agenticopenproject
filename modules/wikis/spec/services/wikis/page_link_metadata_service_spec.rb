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

module Wikis
  FakeMetadata = Data.define(:title, :identifier)
  RSpec.describe PageLinkMetadataService do
    let(:relation) { PageLink.where(provider:) }

    let(:provider) { create(:internal_wiki_provider) }
    let(:page_links) { create_list(:relation_wiki_page_link, 3, provider:) }

    let(:metadata) do
      page_links.map { FakeMetadata.new("Wikis, now with more cheese! Part #{it.id}", it.identifier) }
    end

    subject(:service) { described_class.new(relation) }

    before do
      page_links

      query_double = instance_double(Adapters::Providers::Internal::Queries::PageInfo)
      allow(Adapters::Providers::Internal::Queries::PageInfo).to receive(:new).and_return(query_double)

      allow(query_double).to receive(:call).and_return(Success(metadata))
    end

    it "returns a new relation" do
      service_result = service.call

      expect(service_result).to be_success
      expect(service_result.errors).to be_empty
      expect(service_result.result).to be_an(ActiveRecord::Relation)
    end

    it "adds the title attribute to the metadata association" do
      service_result = service.call
      expect(service_result).to be_success

      page_links = service_result.result
      expect(page_links.first.title).to match(/Wikis, now with more cheese! Part \d+/)
    end
  end
end
