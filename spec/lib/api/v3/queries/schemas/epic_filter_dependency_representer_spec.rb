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

RSpec.describe API::V3::Queries::Schemas::EpicFilterDependencyRepresenter do
  include API::V3::Utilities::PathHelper

  let(:project) { build_stubbed(:project) }
  let(:query) { build_stubbed(:query, project:) }
  let(:filter) { Queries::WorkPackages::Filter::EpicFilter.create!(context: query) }
  let(:operator) { Queries::Operators::Equals }
  let(:instance) { described_class.new(filter, operator, form_embedded: false) }

  describe "#href_callback" do
    subject(:href) { instance.href_callback }

    it "returns the cross-project work_packages endpoint, ignoring the query's project" do
      expect(href).to eq(api_v3_paths.work_packages)
    end

    it "produces the same href regardless of the current project, so cross-project epics are selectable" do
      other_project = build_stubbed(:project)
      other_query = build_stubbed(:query, project: other_project)
      other_filter = Queries::WorkPackages::Filter::EpicFilter.create!(context: other_query)
      other_instance = described_class.new(other_filter, operator, form_embedded: false)

      expect(href).to eq(other_instance.href_callback)
    end

    it "produces the same href for a global (no-project) query" do
      global_query = build_stubbed(:query, project: nil)
      global_filter = Queries::WorkPackages::Filter::EpicFilter.create!(context: global_query)
      global_instance = described_class.new(global_filter, operator, form_embedded: false)

      expect(global_instance.href_callback).to eq(api_v3_paths.work_packages)
    end
  end
end
