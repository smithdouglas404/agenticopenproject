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

RSpec.describe BasicData::TypeSeeder do
  include_context "with basic seed data"

  subject(:seeder) { described_class.new(seed_data) }

  let(:seed_data) { basic_seed_data.merge(Source::SeedData.new(data_hash)) }

  before do
    seeder.seed!
  end

  context "with type descriptions defined" do
    let(:data_hash) do
      YAML.load <<~SEEDING_DATA_YAML
        types:
        - reference: :type_task
          name: Task
          description: "## Summary\\nTask template"
          color_name: :default_color_blue
          is_default: true
          is_in_roadmap: true
          position: 1
        - reference: :type_bug
          name: Bug
          description: "## Summary\\nBug template"
          color_name: red-7
          is_default: false
          is_in_roadmap: true
          position: 2
      SEEDING_DATA_YAML
    end

    it "creates types with the seeded descriptions", :aggregate_failures do
      expect(Type.count).to eq(2)
      expect(Type.find_by(name: "Task")).to have_attributes(
        description: "## Summary\nTask template",
        is_default: true,
        position: 1
      )
      expect(Type.find_by(name: "Bug")).to have_attributes(
        description: "## Summary\nBug template",
        is_default: false,
        position: 2
      )
    end
  end

  context "when type description is omitted" do
    let(:data_hash) do
      YAML.load <<~SEEDING_DATA_YAML
        types:
        - reference: :type_task
          name: Task
          color_name: :default_color_blue
          is_default: true
          is_in_roadmap: true
          position: 1
      SEEDING_DATA_YAML
    end

    it "defaults the description to an empty string" do
      expect(Type.find_by(name: "Task")).to have_attributes(description: "")
    end
  end
end
