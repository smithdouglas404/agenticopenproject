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

require "rails_helper"

RSpec.describe WorkPackages::IdentifierAutofix::PreviewQuery do
  subject(:result) { described_class.new.call }

  let(:display_count) { described_class::DISPLAY_COUNT }

  def create_problematic_project(name:, identifier:)
    create(:project, name:, identifier:)
  end

  def create_valid_project(name:, identifier:)
    create(:project, name:, identifier:)
  end

  context "when there are no problematic projects" do
    before { create_valid_project(name: "Clean Project", identifier: "clean") }

    it "returns total_count 0 and empty projects_data" do
      expect(result.total_count).to eq(0)
      expect(result.projects_data).to be_empty
    end
  end

  context "when a project has underscores in its identifier" do
    before { create_valid_project(name: "My Project", identifier: "my_proj") }

    it "does not flag it as problematic" do
      expect(result.total_count).to eq(0)
      expect(result.projects_data).to be_empty
    end
  end

  context "when there are fewer than DISPLAY_COUNT problematic projects" do
    let!(:problematic) do
      [
        create_problematic_project(name: "Flight Planning", identifier: "flight-planning"),
        create_problematic_project(name: "Very Long Name Project", identifier: "verylongnameproject")
      ]
    end

    it "returns all of them in projects_data" do
      expect(result.projects_data.size).to eq(2)
    end

    it "returns the correct total_count" do
      expect(result.total_count).to eq(2)
    end
  end

  context "when there are more than DISPLAY_COUNT problematic projects" do
    let!(:problematic) do
      Array.new(display_count + 3) do |i|
        create_problematic_project(name: "Project #{i}", identifier: "proj-#{i}")
      end
    end

    it "returns only DISPLAY_COUNT entries in projects_data" do
      expect(result.projects_data.size).to eq(display_count)
    end

    it "returns the full total_count (not capped at DISPLAY_COUNT)" do
      expect(result.total_count).to eq(display_count + 3)
    end
  end

  context "when two problematic projects produce the same base acronym" do
    let!(:first_project)  { create_problematic_project(name: "Flight Planning", identifier: "flight-planning") }
    let!(:second_project) { create_problematic_project(name: "Foxtrot Papa", identifier: "foxtrot-papa") }

    it "does not assign the same handle to both" do
      identifiers = result.projects_data.pluck(:suggested_identifier)
      expect(identifiers.uniq.size).to eq(identifiers.size)
    end
  end

  it "returns Result entries with project, current_identifier, suggested_identifier, and error_reason" do
    create_problematic_project(name: "Alpha Beta", identifier: "alpha-beta")

    entry = result.projects_data.first
    expect(entry).to include(:project, :current_identifier, :suggested_identifier, :error_reason)
  end

  describe "error_reason classification" do
    it "assigns :too_long when identifier length exceeds MAX_IDENTIFIER_LENGTH" do
      create_problematic_project(name: "Test", identifier: "averylongidentifier")
      expect(result.projects_data.first[:error_reason]).to eq(:too_long)
    end

    it "assigns :special_characters when identifier has non-alphanumeric chars but is short" do
      create_problematic_project(name: "Test", identifier: "ab-c")
      expect(result.projects_data.first[:error_reason]).to eq(:special_characters)
    end

    it "assigns :too_long (priority) when identifier is both too long and has special chars" do
      create_problematic_project(name: "Test", identifier: "my-very-long-identifier")
      expect(result.projects_data.first[:error_reason]).to eq(:too_long)
    end
  end
end
