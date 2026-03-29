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

# End-to-end tests verifying that the registry is maintained correctly through
# the full service stack: CreateService, UpdateService, and Projects::UpdateService.
RSpec.describe "SemanticIds registry integration", type: :model do
  shared_let(:role) do
    create(:project_role,
           permissions: %i[view_work_packages add_work_packages edit_work_packages move_work_packages edit_project])
  end
  shared_let(:user) { create(:user) }

  # Projects with uppercase identifiers require alphanumeric mode — stub before creating.
  let(:project) { create(:project, identifier: "PROJ", wp_sequence_counter: 0) }
  let(:target_project) { create(:project, identifier: "DEST", wp_sequence_counter: 0) }

  before do
    allow(Setting::WorkPackageIdentifier).to receive_messages(alphanumeric?: true, numeric?: false)
    create(:member, principal: user, project:, roles: [role])
    create(:member, principal: user, project: target_project, roles: [role])
    login_as(user)
  end

  describe "WP creation via CreateService" do
    let(:attributes) do
      {
        subject: "A new task",
        project:,
        type: project.types.first,
        status: create(:default_status),
        priority: create(:default_priority)
      }
    end

    it "assigns a sequence number, sets semantic_id, and creates a registry entry" do
      result = WorkPackages::CreateService.new(user:).call(**attributes)
      expect(result).to be_success

      wp = result.result
      expect(wp.sequence_number).to eq(1)
      expect(wp.semantic_id).to eq("PROJ-1")

      entry = WorkPackageSemanticId.find_by!(work_package: wp)
      expect(entry.identifier).to eq("PROJ-1")
    end

    it "increments the counter with each new WP" do
      2.times { WorkPackages::CreateService.new(user:).call(**attributes) }
      expect(project.reload.wp_sequence_counter).to eq(2)
      expect(WorkPackageSemanticId.where("identifier LIKE 'PROJ-%'").count).to eq(2)
    end
  end

  describe "WP move via UpdateService" do
    let!(:work_package) do
      # after_create auto-registers as PROJ-1; rename entry to PROJ-5 to simulate an established WP
      create(:work_package, project:).tap do |wp|
        wp.update_columns(sequence_number: 5, semantic_id: "PROJ-5")
        wp.all_semantic_ids.update_all(identifier: "PROJ-5")
        project.update_columns(wp_sequence_counter: 5)
      end
    end

    it "preserves the old identifier and appends a new one in the target project" do
      WorkPackages::UpdateService.new(user:, model: work_package).call(project: target_project)

      expect(WorkPackageSemanticId.find_by(identifier: "PROJ-5")).to be_present
      expect(work_package.reload.semantic_id).to start_with("DEST-")
    end

    it "old identifier still resolves to the WP" do
      WorkPackages::UpdateService.new(user:, model: work_package).call(project: target_project)
      expect(WorkPackage.find_by_identifier("PROJ-5")).to eq(work_package)
    end

    it "new identifier also resolves to the WP" do
      WorkPackages::UpdateService.new(user:, model: work_package).call(project: target_project)
      expect(WorkPackage.find_by_identifier(work_package.reload.semantic_id)).to eq(work_package)
    end
  end

  describe "Project rename via Projects::UpdateService" do
    # after_create auto-registers wp1 as "PROJ-1" (seq=1) and wp2 as "PROJ-2" (seq=2)
    let!(:wp1) { create(:work_package, project:) }
    let!(:wp2) { create(:work_package, project:) }

    it "inserts new-prefix registry entries and updates semantic_id on WPs" do
      Projects::UpdateService.new(user:, model: project).call(identifier: "RENAMED")

      expect(WorkPackageSemanticId.find_by(identifier: "RENAMED-1")).to be_present
      expect(WorkPackageSemanticId.find_by(identifier: "RENAMED-2")).to be_present
      expect(wp1.reload.semantic_id).to eq("RENAMED-1")
      expect(wp2.reload.semantic_id).to eq("RENAMED-2")
    end

    it "preserves old-prefix entries for historic resolution" do
      Projects::UpdateService.new(user:, model: project).call(identifier: "RENAMED")

      expect(WorkPackageSemanticId.find_by(identifier: "PROJ-1")).to be_present
      expect(WorkPackageSemanticId.find_by(identifier: "PROJ-2")).to be_present
    end

    it "old identifiers still resolve to the correct WPs" do
      Projects::UpdateService.new(user:, model: project).call(identifier: "RENAMED")

      expect(WorkPackage.find_by_identifier("PROJ-1")).to eq(wp1)
      expect(WorkPackage.find_by_identifier("PROJ-2")).to eq(wp2)
    end

    it "new identifiers resolve to the correct WPs" do
      Projects::UpdateService.new(user:, model: project).call(identifier: "RENAMED")

      expect(WorkPackage.find_by_identifier("RENAMED-1")).to eq(wp1)
      expect(WorkPackage.find_by_identifier("RENAMED-2")).to eq(wp2)
    end

    it "old prefix still resolves via compute fallback for WPs with no old-prefix registry row" do
      # wp3 is created after the rename, so it only gets a RENAMED-3 row, never PROJ-3
      Projects::UpdateService.new(user:, model: project).call(identifier: "RENAMED")
      wp3 = create(:work_package, project: project.reload)

      # RENAMED-3 resolves via registry
      expect(WorkPackage.find_by_identifier("RENAMED-3")).to eq(wp3)
      # PROJ-3 has no registry row → compute fallback: FriendlyId slug history resolves
      # "PROJ" to the now-renamed project, then matches by sequence_number
      expect(WorkPackage.find_by_identifier("PROJ-3")).to eq(wp3)
    end
  end

  describe "rename + move combinations" do
    let!(:wp1) { create(:work_package, project:) } # auto-registers as PROJ-1

    it "move then rename: old WP identifier resolves under new project prefix" do
      # WP moves to DEST first (retires PROJ-1, creates DEST-1)
      WorkPackages::UpdateService.new(user:, model: wp1).call(project: target_project)
      # PROJ is then renamed to RENAMED (bulk-inserts RENAMED-1 from the retired PROJ-1 row)
      Projects::UpdateService.new(user:, model: project).call(identifier: "RENAMED")

      expect(WorkPackage.find_by_identifier("RENAMED-1")).to eq(wp1)
    end

    it "rename then move: both old identifiers resolve after the WP moves" do
      # PROJ renamed to RENAMED (appends RENAMED-1 registry row, updates semantic_id)
      Projects::UpdateService.new(user:, model: project).call(identifier: "RENAMED")
      # WP moves to DEST (appends DEST-1 registry row, updates semantic_id)
      WorkPackages::UpdateService.new(user:, model: wp1.reload).call(project: target_project)

      expect(WorkPackage.find_by_identifier("PROJ-1")).to eq(wp1)
      expect(WorkPackage.find_by_identifier("RENAMED-1")).to eq(wp1)
    end
  end

  describe "multiple moves" do
    let(:project_c) { create(:project, identifier: "PROJC", wp_sequence_counter: 0) }
    let!(:wp1) { create(:work_package, project:) } # auto-registers as PROJ-1

    before do
      create(:member, principal: user, project: project_c, roles: [role])
    end

    it "all intermediate identifiers resolve after WP moves PROJ → DEST → PROJC" do
      WorkPackages::UpdateService.new(user:, model: wp1).call(project: target_project)
      dest_identifier = wp1.reload.semantic_id

      WorkPackages::UpdateService.new(user:, model: wp1.reload).call(project: project_c)
      projc_identifier = wp1.reload.semantic_id

      expect(WorkPackage.find_by_identifier("PROJ-1")).to eq(wp1)
      expect(WorkPackage.find_by_identifier(dest_identifier)).to eq(wp1)
      expect(WorkPackage.find_by_identifier(projc_identifier)).to eq(wp1)
    end
  end
end
