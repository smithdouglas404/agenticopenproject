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

RSpec.describe WorkPackages::ReallocateIdentifiersOnMoveService do
  subject(:service) { described_class.new(target_project:, source_project_id: source_project.id) }

  let(:source_project) { create(:project, identifier: "SRC") }
  let(:target_project) { create(:project, identifier: "TGT") }

  # Simulate a WP that was created in source_project (callback allocates "SRC-N")
  # and then moved to target_project via UpdateService (which nils sequence_number
  # to avoid unique index collisions, then saves with the new project_id).
  # We use update! to preserve dirty tracking so project_id_before_last_save works.
  let(:work_package) do
    create(:work_package, project: source_project).tap do |wp|
      wp.update!(project: target_project, sequence_number: nil)
    end
  end

  context "when in alphanumeric mode",
          with_settings: { work_packages_identifier: Setting::WorkPackageIdentifier::ALPHANUMERIC } do
    it "allocates a new identifier in the target project" do
      service.call([work_package])

      work_package.reload
      expect(work_package.identifier).to eq("TGT-1")
      expect(work_package.sequence_number).to eq(1)
    end

    it "increments the target project's wp_sequence_counter" do
      service.call([work_package])

      expect(target_project.reload.wp_sequence_counter).to eq(1)
    end

    it "records the move in work_package_moves" do
      service.call([work_package])

      move = WorkPackageMove.find_by(work_package_id: work_package.id)
      expect(move).to be_present
      expect(move.source_project_id).to eq(source_project.id)
      expect(move.sequence_number).to eq(1)
    end

    it "makes the old identifier resolvable via move resolution" do
      service.call([work_package])

      expect(WorkPackage.find("SRC-1")).to eq(work_package)
      expect(WorkPackage.find("TGT-1")).to eq(work_package)
    end

    it "continues from the target project's existing counter" do
      target_project.update_column(:wp_sequence_counter, 5)

      service.call([work_package])

      expect(work_package.reload.sequence_number).to eq(6)
      expect(work_package.identifier).to eq("TGT-6")
    end

    it "allocates sequential numbers for multiple work packages" do
      wp2 = create(:work_package, project: source_project).tap do |wp|
        wp.update!(project: target_project, sequence_number: nil)
      end

      service.call([work_package, wp2])

      expect(work_package.reload.identifier).to eq("TGT-1")
      expect(wp2.reload.identifier).to eq("TGT-2")
    end

    it "skips work packages without identifiers" do
      wp_without_id = create(:work_package, project: source_project)
      wp_without_id.update_columns(identifier: nil, sequence_number: nil)
      wp_without_id.update!(project: target_project)

      expect { service.call([wp_without_id]) }
        .not_to change { target_project.reload.wp_sequence_counter }
    end
  end

  context "when in numeric mode",
          with_settings: { work_packages_identifier: Setting::WorkPackageIdentifier::NUMERIC } do
    let(:source_project) { create(:project, identifier: "src") }
    let(:target_project) { create(:project, identifier: "tgt") }

    let(:work_package) do
      create(:work_package, project: source_project).tap do |wp|
        wp.update!(project: target_project)
      end
    end

    it "is a no-op" do
      expect { service.call([work_package]) }
        .not_to change { target_project.reload.wp_sequence_counter }

      expect(work_package.reload.identifier).to be_nil
    end
  end
end
