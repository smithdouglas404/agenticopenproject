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
  RSpec.describe PageLinkMetadataService do
    let(:relation) { PageLink.limit(30) }

    shared_let(:provider) { create(:internal_wiki_provider) }
    shared_let(:page_links) { create_list(:relation_wiki_page_link, 3, provider:) }

    subject(:service) { described_class }

    before do
      query_double = instance_double(Adapters::Providers::Internal::Queries::PageInfo)
      query_class_double = class_double(Adapters::Providers::Internal::Queries::PageInfo, new: query_double)
      Adapters::Registry.stub("internal.queries.page_info", query_class_double)

      build_inputs.each do |input|
        allow(query_double).to receive(:call).with(input).and_return(
          Success(
            Adapters::Results::PageInfo.new(title: "Wikis, now with more cheese! Part #{input.identifier}",
                                            identifier: input.identifier,
                                            href: "totally_valid_url",
                                            provider:)
          )
        )
      end
    end

    it "returns a new relation" do
      service_result = service.call(relation)

      expect(service_result).to be_success
      expect(service_result.errors).to be_empty
      expect(service_result.result).to be_an(ActiveRecord::Relation)
    end

    it "adds the title attribute to the metadata association" do
      service_result = service.call(relation)
      expect(service_result).to be_success

      page_links = service_result.result
      expect(page_links.first.title).to eq("Wikis, now with more cheese! Part #{page_links.first.identifier}")
    end

    private

    def build_inputs
      page_links.filter_map { Adapters::Input::PageInfo.build(identifier: it.identifier).value_or(nil) }
    end
  end
end
