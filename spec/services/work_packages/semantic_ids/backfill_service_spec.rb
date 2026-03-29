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

RSpec.describe WorkPackages::SemanticIds::BackfillService do
  before do
    allow(Setting::WorkPackageIdentifier).to receive_messages(alphanumeric?: true, numeric?: false)
  end

  let(:project) { create(:project, identifier: "PROJ", wp_sequence_counter: 0) }

  describe ".run" do
    context "when WPs already have sequence numbers" do
      let!(:wp1) { create(:work_package, project:, sequence_number: 1) }
      let!(:wp2) { create(:work_package, project:, sequence_number: 2) }

      before { project.update_columns(wp_sequence_counter: 2) }

      it "creates registry entries for each WP" do
        described_class.run
        expect(WorkPackageSemanticAlias.find_by!(work_package: wp1).identifier).to eq("PROJ-1")
        expect(WorkPackageSemanticAlias.find_by!(work_package: wp2).identifier).to eq("PROJ-2")
      end

      it "sets semantic_id on each WP" do
        described_class.run
        expect(wp1.reload.semantic_id).to eq("PROJ-1")
        expect(wp2.reload.semantic_id).to eq("PROJ-2")
      end

      it "does not duplicate entries on re-run" do
        described_class.run
        expect { described_class.run }
          .not_to change(WorkPackageSemanticAlias, :count)
      end
    end

    context "when WPs have no sequence number" do
      # after_create auto-registers; reset to simulate legacy data with no sequence/registry
      let!(:wp1) do
        create(:work_package, project:).tap do |wp|
          wp.all_semantic_ids.delete_all
          wp.update_columns(sequence_number: nil)
        end
      end
      let!(:wp2) do
        create(:work_package, project:).tap do |wp|
          wp.all_semantic_ids.delete_all
          wp.update_columns(sequence_number: nil)
        end
      end

      before { project.update_columns(wp_sequence_counter: 0) }

      it "assigns sequence numbers in id order" do
        described_class.run
        # IDs are ascending, so wp1 gets 1 and wp2 gets 2
        expect(wp1.reload.sequence_number).to be < wp2.reload.sequence_number
      end

      it "sets the project counter to the highest assigned sequence" do
        described_class.run
        expect(project.reload.wp_sequence_counter).to eq(2)
      end

      it "creates registry entries for each WP" do
        described_class.run
        expect(WorkPackageSemanticAlias.where(work_package: wp1)).to be_present
        expect(WorkPackageSemanticAlias.where(work_package: wp2)).to be_present
      end
    end

    context "when WPs are partially sequenced" do
      # Simulate legacy state: wp_with_seq already registered as PROJ-3, wp_without_seq unregistered
      let!(:wp_with_seq) do
        create(:work_package, project:).tap do |wp|
          wp.update_columns(sequence_number: 3)
          wp.all_semantic_ids.update_all(identifier: "PROJ-3")
        end
      end
      let!(:wp_without_seq) do
        create(:work_package, project:).tap do |wp|
          wp.all_semantic_ids.delete_all
          wp.update_columns(sequence_number: nil)
        end
      end

      before { project.update_columns(wp_sequence_counter: 3) }

      it "assigns sequence numbers only to unsequenced WPs" do
        described_class.run
        expect(wp_with_seq.reload.sequence_number).to eq(3)
        expect(wp_without_seq.reload.sequence_number).to eq(4)
      end

      it "updates the project counter correctly" do
        described_class.run
        expect(project.reload.wp_sequence_counter).to eq(4)
      end
    end

    context "when processing multiple projects" do
      let(:other_project) { create(:project, identifier: "OTHP", wp_sequence_counter: 0) }
      let!(:wp_proj) { create(:work_package, project:, sequence_number: nil) }
      let!(:wp_other) { create(:work_package, project: other_project, sequence_number: nil) }

      it "processes each project independently" do
        described_class.run
        expect(WorkPackageSemanticAlias.find_by!(work_package: wp_proj).identifier).to start_with("PROJ-")
        expect(WorkPackageSemanticAlias.find_by!(work_package: wp_other).identifier).to start_with("OTHP-")
      end
    end
  end
end
