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
    allow(Setting::WorkPackageIdentifier).to receive(:alphanumeric?).and_return(true)
    allow(Setting::WorkPackageIdentifier).to receive(:numeric?).and_return(false)
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

    it "assigns a sequence number and creates a current registry entry" do
      result = WorkPackages::CreateService.new(user:).call(**attributes)
      expect(result).to be_success

      wp = result.result
      expect(wp.sequence_number).to eq(1)

      entry = WorkPackageSemanticId.find_by!(work_package: wp)
      expect(entry.identifier).to eq("PROJ-1")
      expect(entry.current).to be(true)
    end

    it "increments the counter with each new WP" do
      2.times { WorkPackages::CreateService.new(user:).call(**attributes) }
      expect(project.reload.wp_sequence_counter).to eq(2)
      expect(WorkPackageSemanticId.where("identifier LIKE 'PROJ-%'").count).to eq(2)
    end
  end

  describe "WP move via UpdateService" do
    let!(:work_package) do
      create(:work_package, project:, sequence_number: 5).tap do |wp|
        WorkPackageSemanticId.create!(identifier: "PROJ-5", work_package: wp, current: true)
        project.update_columns(wp_sequence_counter: 5)
      end
    end

    it "retires the old identifier and creates a new one in the target project" do
      WorkPackages::UpdateService.new(user:, model: work_package).call(project: target_project)

      expect(WorkPackageSemanticId.find_by!(identifier: "PROJ-5").current).to be(false)

      new_entry = WorkPackageSemanticId.find_by!(work_package: work_package.reload, current: true)
      expect(new_entry.identifier).to start_with("DEST-")
    end

    it "old identifier still resolves to the WP" do
      WorkPackages::UpdateService.new(user:, model: work_package).call(project: target_project)
      expect(WorkPackage.find_by_identifier("PROJ-5")).to eq(work_package)
    end

    it "new identifier also resolves to the WP" do
      WorkPackages::UpdateService.new(user:, model: work_package).call(project: target_project)
      new_identifier = WorkPackageSemanticId.find_by!(work_package: work_package.reload, current: true).identifier
      expect(WorkPackage.find_by_identifier(new_identifier)).to eq(work_package)
    end
  end

  describe "Project rename via Projects::UpdateService" do
    let!(:wp1) do
      create(:work_package, project:, sequence_number: 1).tap do |wp|
        WorkPackageSemanticId.create!(identifier: "PROJ-1", work_package: wp, current: true)
      end
    end
    let!(:wp2) do
      create(:work_package, project:, sequence_number: 2).tap do |wp|
        WorkPackageSemanticId.create!(identifier: "PROJ-2", work_package: wp, current: true)
      end
    end

    before { project.update_columns(wp_sequence_counter: 2) }

    it "creates new current entries with the new prefix" do
      Projects::UpdateService.new(user:, model: project).call(identifier: "RENAMED")

      expect(WorkPackageSemanticId.find_by!(identifier: "RENAMED-1").current).to be(true)
      expect(WorkPackageSemanticId.find_by!(identifier: "RENAMED-2").current).to be(true)
    end

    it "retires old-prefix entries" do
      Projects::UpdateService.new(user:, model: project).call(identifier: "RENAMED")

      expect(WorkPackageSemanticId.find_by!(identifier: "PROJ-1").current).to be(false)
      expect(WorkPackageSemanticId.find_by!(identifier: "PROJ-2").current).to be(false)
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
  end
end
