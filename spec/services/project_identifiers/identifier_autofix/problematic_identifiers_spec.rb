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

RSpec.describe ProjectIdentifiers::IdentifierAutofix::ProblematicIdentifiers do
  subject(:analysis) { described_class.new }

  # Bypasses model validations to set an exact identifier in the database,
  # allowing tests to simulate identifiers from any format mode.
  def set_raw_identifier(project, identifier)
    Project.where(id: project.id).update_all(identifier:)
    project.reload
  end

  def create_project_with_raw_identifier(name:, identifier:)
    set_raw_identifier(create(:project, name:), identifier)
  end

  describe "#scope" do
    it "includes projects with identifiers exceeding max length" do
      project = create_project_with_raw_identifier(name: "Test", identifier: "averylongidentifier")
      expect(analysis.scope).to include(Project.find(project.id))
    end

    it "includes projects with non-alphanumeric characters" do
      project = create_project_with_raw_identifier(name: "Test", identifier: "ab-c")
      expect(analysis.scope).to include(Project.find(project.id))
    end

    it "includes projects with identifiers starting with a digit" do
      project = create_project_with_raw_identifier(name: "Test", identifier: "1abc")
      expect(analysis.scope).to include(Project.find(project.id))
    end

    it "includes projects with non-uppercased identifiers" do
      project = create_project_with_raw_identifier(name: "Test", identifier: "proj")
      expect(analysis.scope).to include(Project.find(project.id))
    end

    it "excludes valid uppercased alphanumeric identifiers" do
      project = create_project_with_raw_identifier(name: "Valid", identifier: "VALID")
      expect(analysis.scope).not_to include(Project.find(project.id))
    end
  end

  describe "#count" do
    it "returns the number of problematic projects" do
      create_project_with_raw_identifier(name: "A", identifier: "a-b")
      create_project_with_raw_identifier(name: "B", identifier: "c-d")
      create_project_with_raw_identifier(name: "C", identifier: "VALID")

      expect(analysis.count).to eq(2)
    end
  end

  describe "#error_reason" do
    it "returns :too_long when identifier exceeds max length" do
      expect(analysis.error_reason("averylongidentifier")).to eq(:too_long)
    end

    it "returns :numerical when identifier is purely numeric" do
      expect(analysis.error_reason("12345")).to eq(:numerical)
    end

    it "returns :starts_with_number when identifier begins with a digit" do
      expect(analysis.error_reason("1abc")).to eq(:starts_with_number)
    end

    it "returns :special_characters when identifier has non-alphanumeric chars" do
      expect(analysis.error_reason("ab-c")).to eq(:special_characters)
    end

    it "returns :not_fully_uppercased when identifier is lowercase but otherwise valid" do
      expect(analysis.error_reason("proj")).to eq(:not_fully_uppercased)
    end

    it "returns :too_long with priority over :special_characters" do
      expect(analysis.error_reason("my-very-long-identifier")).to eq(:too_long)
    end

    it "returns :in_use when identifier belongs to a non-problematic project" do
      create_project_with_raw_identifier(name: "Taken", identifier: "TAKEN")
      expect(analysis.error_reason("TAKEN")).to eq(:in_use)
    end

    it "returns :reserved when identifier is a historical slug of another project" do
      project = create_project_with_raw_identifier(name: "Gamma", identifier: "GAMMA")
      FriendlyId::Slug.create!(slug: "OLDIE", sluggable: project)

      expect(analysis.error_reason("OLDIE")).to eq(:reserved)
    end

    it "returns :unknown when no classification matches" do
      expect(analysis.error_reason("VALID")).to eq(:unknown)
    end
  end

  describe "#exclusion_set" do
    subject(:exclusion) { analysis.exclusion_set }

    let!(:valid_project) { create_project_with_raw_identifier(name: "Alpha", identifier: "ALPHA") }

    before do
      create_project_with_raw_identifier(name: "Beta", identifier: "beta-project")
    end

    it "returns a Set" do
      expect(exclusion).to be_a(Set)
    end

    it "includes identifiers from non-problematic projects" do
      expect(exclusion).to include("ALPHA")
    end

    it "includes historical slugs (reserved identifiers)" do
      FriendlyId::Slug.create!(slug: "OLDALPHA", sluggable_id: valid_project.id, sluggable_type: "Project")

      expect(exclusion).to include("OLDALPHA")
    end

    it "excludes identifiers from problematic projects" do
      expect(exclusion).not_to include("beta-project")
    end
  end
end
