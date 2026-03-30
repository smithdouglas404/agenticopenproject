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

RSpec.describe WorkPackages::IdentifierAutofix::ApplyHandlesJob do
  subject(:job) { described_class.new }

  # Simulate legacy (numeric) mode — the job runs before flipping the switch.
  # In this mode the WP after_create hook does not auto-assign sequence numbers,
  # so WPs start with sequence_number: nil and semantic_id: nil.
  before do
    allow(Setting::WorkPackageIdentifier).to receive_messages(alphanumeric?: false, numeric?: true)
  end

  describe "#perform" do
    context "when projects have legacy (non-semantic) identifiers" do
      # acts_as_url generates lowercase slug identifiers in numeric mode, e.g. "my-project"
      let!(:project) { create(:project, name: "My Project") }
      let!(:wp1)     { create(:work_package, project:) }
      let!(:wp2)     { create(:work_package, project:) }

      before { job.perform }

      it "assigns a valid semantic identifier to the project" do
        expect(project.reload.identifier).to match(/\A[A-Z][A-Z0-9_]{1,9}\z/)
      end

      it "assigns sequence numbers in id (oldest-first) order" do
        expect(wp1.reload.sequence_number).to eq(1)
        expect(wp2.reload.sequence_number).to eq(2)
      end

      it "sets semantic_id on each WP using the new identifier" do
        new_id = project.reload.identifier
        expect(wp1.reload.semantic_id).to eq("#{new_id}-1")
        expect(wp2.reload.semantic_id).to eq("#{new_id}-2")
      end
    end

    context "when a project already has a valid semantic identifier" do
      let!(:project) do
        create(:project).tap { |p| p.update_columns(identifier: "MYAPP", wp_sequence_counter: 0) }
      end
      let!(:wp) { create(:work_package, project:) }

      before { job.perform }

      it "leaves the identifier unchanged" do
        expect(project.reload.identifier).to eq("MYAPP")
      end

      it "still backfills the WP" do
        expect(wp.reload.sequence_number).to eq(1)
        expect(wp.reload.semantic_id).to eq("MYAPP-1")
      end
    end

    context "when a WP already has a sequence number but no semantic_id" do
      let!(:project) do
        create(:project).tap { |p| p.update_columns(identifier: "VALID", wp_sequence_counter: 5) }
      end
      let!(:wp) { create(:work_package, project:).tap { |w| w.update_columns(sequence_number: 5, semantic_id: nil) } }

      before { job.perform }

      it "does not reassign the existing sequence number" do
        expect(wp.reload.sequence_number).to eq(5)
      end

      it "derives and sets semantic_id from the existing sequence number" do
        expect(wp.reload.semantic_id).to eq("VALID-5")
      end
    end

    context "when multiple problematic projects could collide on the same suggestion" do
      # Both names produce the same initials ("MP"), forcing the second to expand.
      let!(:project_a) { create(:project, name: "My Project") }
      let!(:project_b) { create(:project, name: "Monster Project") }

      before { job.perform }

      it "assigns distinct identifiers to each project" do
        expect(project_a.reload.identifier).not_to eq(project_b.reload.identifier)
      end

      it "assigns valid semantic identifiers to both" do
        [project_a, project_b].each do |p|
          expect(p.reload.identifier).to match(/\A[A-Z][A-Z0-9_]{1,9}\z/)
        end
      end
    end

    it "flips the work_packages_identifier setting to alphanumeric" do
      job.perform
      expect(Setting.work_packages_identifier).to eq(Setting::WorkPackageIdentifier::ALPHANUMERIC)
    end
  end
end
