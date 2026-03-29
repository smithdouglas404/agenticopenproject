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

RSpec.describe WorkPackageSemanticAlias, "registry" do # rubocop:disable RSpec/SpecFilePathFormat
  before do
    allow(Setting::WorkPackageIdentifier).to receive_messages(alphanumeric?: true, numeric?: false)
  end

  let(:project) { create(:project, identifier: "PROJ", wp_sequence_counter: 0) }
  let(:target_project) { create(:project, identifier: "OTHER", wp_sequence_counter: 0) }
  # after_create auto-registers work_package as "PROJ-1" (sequence_number: 1)
  let(:work_package) { create(:work_package, project:) }

  describe ".register_move" do
    before { work_package } # trigger auto-registration as "PROJ-1"

    it "appends a new registry entry in the target project" do
      work_package.update_columns(project_id: target_project.id)
      described_class.register_move(work_package)
      new_entry = described_class.find_by!(identifier: "OTHER-1")
      expect(new_entry.work_package).to eq(work_package)
    end

    it "updates sequence_number and semantic_id to the target project's values" do
      work_package.update_columns(project_id: target_project.id)
      described_class.register_move(work_package)
      expect(work_package.reload.sequence_number).to eq(1)
      expect(work_package.reload.semantic_id).to eq("OTHER-1")
    end

    it "preserves the old entry for historic lookups" do
      work_package.update_columns(project_id: target_project.id)
      described_class.register_move(work_package)
      expect(described_class.find_by(identifier: "PROJ-1")).to be_present
    end
  end

  describe ".register_project_rename" do
    # after_create auto-registers wp1 as "PROJ-1" and wp2 as "PROJ-2"
    let(:wp1) { create(:work_package, project:) }
    let(:wp2) { create(:work_package, project:) }

    before do
      wp1
      wp2
      project.update_columns(identifier: "NEWPROJ")
    end

    it "inserts new-prefix registry entries" do
      described_class.register_project_rename(project, "PROJ")
      expect(described_class.find_by(identifier: "NEWPROJ-1")).to be_present
      expect(described_class.find_by(identifier: "NEWPROJ-2")).to be_present
    end

    it "updates semantic_id on work packages to the new prefix" do
      described_class.register_project_rename(project, "PROJ")
      expect(wp1.reload.semantic_id).to eq("NEWPROJ-1")
      expect(wp2.reload.semantic_id).to eq("NEWPROJ-2")
    end

    it "keeps the old-prefix rows for historic resolution" do
      described_class.register_project_rename(project, "PROJ")
      expect(described_class.find_by(identifier: "PROJ-1")).to be_present
      expect(described_class.find_by(identifier: "PROJ-2")).to be_present
    end

    it "is idempotent (safe to run twice)" do
      described_class.register_project_rename(project, "PROJ")
      expect { described_class.register_project_rename(project, "PROJ") }
        .not_to raise_error
    end

    context "when a WP has since moved away from the project" do
      before do
        # Simulate wp1 having moved: its semantic_id now belongs to another project
        wp1.update_columns(semantic_id: "OTHER-99", sequence_number: 99)
      end

      it "still creates a new NEWPROJ entry for that WP because it was in the old registry" do
        described_class.register_project_rename(project, "PROJ")
        expect(described_class.find_by(identifier: "NEWPROJ-1")).to be_present
      end

      it "uses the sequence number from the old registry row, not the WP's current sequence" do
        described_class.register_project_rename(project, "PROJ")
        # NEWPROJ-1 must be created (from "PROJ-1"), not NEWPROJ-99
        expect(described_class.find_by(identifier: "NEWPROJ-1")).to be_present
        expect(described_class.find_by(identifier: "NEWPROJ-99")).to be_nil
      end

      it "does not update semantic_id on the moved-away WP" do
        described_class.register_project_rename(project, "PROJ")
        expect(wp1.reload.semantic_id).to eq("OTHER-99")
      end
    end
  end
end
