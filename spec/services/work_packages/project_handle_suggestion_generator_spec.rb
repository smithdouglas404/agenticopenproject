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

# Integration-style spec: real Project records are created in the test DB so that
# both the SQL query (WHERE length(identifier) > 10 OR identifier ~ '[^a-zA-Z0-9]')
# and the suggestion algorithm are exercised end-to-end.
RSpec.describe WorkPackages::ProjectHandleSuggestionGenerator do
  describe ".call" do
    context "when all existing projects have valid identifiers" do
      it "returns an empty array" do
        expect(described_class.call).to be_empty
      end
    end

    context "when a project has a too-long identifier" do
      shared_let(:project) { create(:project, identifier: "verylongidentifier", name: "Very Long Identifier") }

      it "returns one suggestion entry for the project" do
        result = described_class.call
        expect(result.size).to eq(1)
        expect(result.first[:project]).to eq(project)
        expect(result.first[:current_identifier]).to eq("verylongidentifier")
        expect(result.first[:error_reason]).to eq(:too_long)
        expect(result.first[:suggested_handle]).to be_present
        expect(result.first[:suggested_handle].length).to be <= 10
      end
    end

    context "when a project has a special-character identifier" do
      shared_let(:project) { create(:project, identifier: "fly-sky", name: "Fly Sky") }

      it "returns a suggestion entry with error_reason :special_characters" do
        result = described_class.call
        expect(result.size).to eq(1)
        expect(result.first[:error_reason]).to eq(:special_characters)
      end
    end

    context "when multiple projects generate conflicting handles" do
      shared_let(:project_sc1) { create(:project, identifier: "sc-app",         name: "Stream Communicator") }
      shared_let(:project_sc2) { create(:project, identifier: "stream-channel", name: "Stream Channel") }

      it "generates unique handles for each project" do
        handles = described_class.call.pluck(:suggested_handle)
        expect(handles.uniq.size).to eq(handles.size)
      end

      it "appends a numeric suffix to resolve conflicts" do
        handles = described_class.call.pluck(:suggested_handle)
        expect(handles).to include("SC")
        expect(handles.any? { |h| h.match?(/\ASC\d+\z/) }).to be true
      end
    end
  end

  describe "handle generation from project name" do
    # Each example creates one project whose identifier has a hyphen (special char)
    # so the SQL query picks it up, then asserts the suggested handle from the name.
    {
      "Flight Planning Algorithm" => "FPA",
      "Fly & Sky" => "FS",
      "Social media marketing" => "SMM",
      "Arcanos (mobile-web-app)" => "AMWA",
      "Flight Planning Training" => "FPT",
      "A B C D E F G H I J K" => "ABCDEFGHIJ", # truncated to 10 chars
      "Cécile Martin" => "CM", # Unicode: "Cécile" is one word, not ["C","cile"]
      "étude de cas" => "EDC" # Unicode: é→E via transliteration
    }.each do |project_name, expected_handle|
      it "generates '#{expected_handle}' from '#{project_name}'" do
        create(:project, identifier: "bad-id", name: project_name)
        expect(described_class.call.first[:suggested_handle]).to eq(expected_handle)
      end
    end
  end

  describe "unique_handle conflict resolution" do
    it "uses the base handle when not yet taken" do
      create(:project, identifier: "sc-app", name: "Stream Communicator")
      expect(described_class.call.first[:suggested_handle]).to eq("SC")
    end

    it "appends '2' when the base is already taken" do
      create(:project, identifier: "sc-app",    name: "Stream Communicator")
      create(:project, identifier: "stream-ch", name: "Stream Channel")
      expect(described_class.call.pluck(:suggested_handle)).to contain_exactly("SC", "SC2")
    end

    it "increments the suffix until unique" do
      create(:project, identifier: "sc-a", name: "Stream Communicator")
      create(:project, identifier: "sc-b", name: "Stream Channel")
      create(:project, identifier: "sc-c", name: "Something Cool")
      expect(described_class.call.pluck(:suggested_handle)).to contain_exactly("SC", "SC2", "SC3")
    end

    it "trims the base to fit within HANDLE_MAX_LENGTH when adding a suffix" do
      create(:project, identifier: "a-b-c-d-e-f-g-h-i-j", name: "A B C D E F G H I J")
      create(:project, identifier: "a-b-c-d-e-f-g-h-i-j-x", name: "A B C D E F G H I J")
      handles = described_class.call.pluck(:suggested_handle)
      expect(handles.all? { |h| h.length <= 10 }).to be true
      expect(handles.uniq.size).to eq(2)
    end
  end

  describe "error reason assignment" do
    it "assigns :too_long when identifier length exceeds HANDLE_MAX_LENGTH" do
      create(:project, identifier: "verylongidentifier", name: "Test")
      expect(described_class.call.first[:error_reason]).to eq(:too_long)
    end

    it "assigns :special_characters when identifier has non-alphanumeric chars but is short" do
      create(:project, identifier: "my-project", name: "Test")
      expect(described_class.call.first[:error_reason]).to eq(:special_characters)
    end

    it "assigns :too_long (priority) when identifier is both too long and has special chars" do
      create(:project, identifier: "my-very-long-identifier", name: "Test")
      expect(described_class.call.first[:error_reason]).to eq(:too_long)
    end
  end
end
