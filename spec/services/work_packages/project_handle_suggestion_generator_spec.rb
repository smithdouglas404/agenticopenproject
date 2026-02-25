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

RSpec.describe WorkPackages::ProjectHandleSuggestionGenerator do
  # Stub the SQL query chain used by #call.
  # The WHERE clause in production filters out valid identifiers; tests control
  # what the query "returns" by mocking the end of the chain.
  def stub_query(projects)
    allow(Project).to receive_message_chain(:select, :where, :to_a).and_return(projects) # rubocop:disable RSpec/MessageChain
  end

  describe ".call" do
    context "when the query returns no projects (all identifiers are valid)" do
      before { stub_query([]) }

      it "returns an empty array" do
        expect(described_class.call).to be_empty
      end
    end

    context "when the query returns a project with a too-long identifier" do
      let(:project) { instance_double(Project, identifier: "verylongidentifier", name: "Very Long Identifier") }

      before { stub_query([project]) }

      it "returns a suggestion entry for the project" do
        result = described_class.call
        expect(result.size).to eq(1)
        expect(result.first[:project]).to eq(project)
        expect(result.first[:current_identifier]).to eq("verylongidentifier")
        expect(result.first[:error_reason]).to eq(:too_long)
        expect(result.first[:suggested_handle]).to be_present
        expect(result.first[:suggested_handle].length).to be <= 10
      end
    end

    context "when the query returns a project with a special-character identifier" do
      let(:project) { instance_double(Project, identifier: "fly-sky", name: "Fly Sky") }

      before { stub_query([project]) }

      it "returns a suggestion entry with error_reason :special_characters" do
        result = described_class.call
        expect(result.size).to eq(1)
        expect(result.first[:error_reason]).to eq(:special_characters)
      end
    end

    context "when multiple projects would generate conflicting handles" do
      let(:project_sc1) { instance_double(Project, identifier: "sc-app", name: "Stream Communicator") }
      let(:project_sc2) { instance_double(Project, identifier: "stream-channel", name: "Stream Channel") }

      before { stub_query([project_sc1, project_sc2]) }

      it "generates unique handles for each project" do
        result = described_class.call
        handles = result.pluck(:suggested_handle)
        expect(handles.uniq.size).to eq(handles.size)
      end

      it "appends a numeric suffix to resolve conflicts" do
        result = described_class.call
        handles = result.pluck(:suggested_handle)
        # "Stream Communicator" → "SC", "Stream Channel" → "SC2"
        expect(handles).to include("SC")
        expect(handles.any? { |h| h.match?(/\ASC\d+\z/) }).to be true
      end
    end
  end

  describe "handle generation from project name" do
    {
      "Flight Planning Algorithm" => "FPA",
      "Fly & Sky" => "FS",
      "Social media marketing" => "SMM",
      "Arcanos Mobile Web App" => "AMWA",
      "Flight Planning Training" => "FPT",
      "A B C D E F G H I J K" => "ABCDEFGHIJ" # truncated to 10 chars
    }.each do |project_name, expected_handle|
      it "generates '#{expected_handle}' from '#{project_name}'" do
        project = instance_double(Project, identifier: "bad-id", name: project_name)
        stub_query([project])
        expect(described_class.call.first[:suggested_handle]).to eq(expected_handle)
      end
    end
  end

  describe "unique_handle conflict resolution" do
    it "uses the base handle when it is not yet taken" do
      project = instance_double(Project, identifier: "sc-app", name: "Stream Communicator")
      stub_query([project])
      expect(described_class.call.first[:suggested_handle]).to eq("SC")
    end

    it "appends '2' when the base is already taken" do
      p1 = instance_double(Project, identifier: "sc-app",      name: "Stream Communicator")
      p2 = instance_double(Project, identifier: "stream-ch",   name: "Stream Channel")
      stub_query([p1, p2])
      handles = described_class.call.pluck(:suggested_handle)
      expect(handles).to contain_exactly("SC", "SC2")
    end

    it "increments the suffix until unique" do
      p1 = instance_double(Project, identifier: "sc-a", name: "Stream Communicator")
      p2 = instance_double(Project, identifier: "sc-b", name: "Stream Channel")
      p3 = instance_double(Project, identifier: "sc-c", name: "Something Cool")
      stub_query([p1, p2, p3])
      handles = described_class.call.pluck(:suggested_handle)
      expect(handles).to contain_exactly("SC", "SC2", "SC3")
    end

    it "trims the base to fit within HANDLE_MAX_LENGTH when adding a suffix" do
      # 10-char acronym: "ABCDEFGHIJ"
      project1 = instance_double(Project, identifier: "a-b-c-d-e-f-g-h-i-j-k",
                                          name: "A B C D E F G H I J")
      project2 = instance_double(Project, identifier: "a-b-c-d-x",
                                          name: "A B C D E F G H I J") # same acronym
      stub_query([project1, project2])
      handles = described_class.call.pluck(:suggested_handle)
      expect(handles.all? { |h| h.length <= 10 }).to be true
      expect(handles.uniq.size).to eq(2)
    end
  end

  describe "error reason assignment" do
    context "when identifier is too long" do
      it "assigns :too_long" do
        project = instance_double(Project, identifier: "verylongidentifier", name: "Test")
        stub_query([project])
        expect(described_class.call.first[:error_reason]).to eq(:too_long)
      end
    end

    context "when identifier contains special characters but is not too long" do
      it "assigns :special_characters" do
        project = instance_double(Project, identifier: "my-project", name: "Test")
        stub_query([project])
        expect(described_class.call.first[:error_reason]).to eq(:special_characters)
      end
    end

    context "when identifier is both too long and has special chars" do
      it "assigns :too_long (length takes priority)" do
        project = instance_double(Project, identifier: "my-very-long-identifier", name: "Test")
        stub_query([project])
        expect(described_class.call.first[:error_reason]).to eq(:too_long)
      end
    end
  end
end
