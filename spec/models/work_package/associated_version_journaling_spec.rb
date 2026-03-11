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

RSpec.describe "WorkPackage associated_versions journaling", # rubocop:disable RSpec/DescribeClass
               with_settings: { journal_aggregation_time_minutes: 0 } do
  shared_let(:project) { create(:project) }
  shared_let(:user) do
    create(:user, member_with_permissions: { project => %i[view_work_packages edit_work_packages] })
  end
  shared_let(:version1) { create(:version, name: "Sprint 1", project:) }
  shared_let(:version2) { create(:version, name: "Sprint 2", project:) }
  shared_let(:work_package) { create(:work_package, project:) }

  before { login_as(user) }

  def update_wp(attrs)
    WorkPackages::UpdateService.new(user:, model: work_package).call(**attrs)
  end

  context "with target_versions" do
    it "creates a journal entry when a version is added" do
      expect do
        update_wp(target_version_ids: [version1.id])
      end.to change(Journal::WorkPackageAssociatedVersionJournal, :count).by(1)

      last_journal = work_package.journals.last
      expect(last_journal.details).to have_key("target_versions_#{version1.id}")
      expect(last_journal.details["target_versions_#{version1.id}"]).to eq([nil, "Sprint 1"])
    end

    it "creates a journal entry when a version is removed" do
      update_wp(target_version_ids: [version1.id])
      work_package.reload

      expect do
        update_wp(target_version_ids: [])
      end.to change(Journal, :count).by(1)

      last_journal = work_package.journals.last
      expect(last_journal.details).to have_key("target_versions_#{version1.id}")
      expect(last_journal.details["target_versions_#{version1.id}"]).to eq(["Sprint 1", nil])
    end

    it "creates a journal entry recording both add and remove when versions are swapped" do
      update_wp(target_version_ids: [version1.id])
      work_package.reload

      update_wp(target_version_ids: [version2.id])

      last_journal = work_package.journals.last
      expect(last_journal.details).to have_key("target_versions_#{version1.id}")
      expect(last_journal.details["target_versions_#{version1.id}"]).to eq(["Sprint 1", nil])
      expect(last_journal.details).to have_key("target_versions_#{version2.id}")
      expect(last_journal.details["target_versions_#{version2.id}"]).to eq([nil, "Sprint 2"])
    end

    it "does not create a new journal when target_versions are unchanged" do
      update_wp(target_version_ids: [version1.id])
      work_package.reload

      expect do
        update_wp(target_version_ids: [version1.id])
      end.not_to change(Journal, :count)
    end
  end

  context "with observed_in_versions" do
    it "creates a journal entry when a version is added" do
      expect do
        update_wp(observed_in_version_ids: [version1.id])
      end.to change(Journal::WorkPackageAssociatedVersionJournal, :count).by(1)

      last_journal = work_package.journals.last
      expect(last_journal.details).to have_key("observed_in_versions_#{version1.id}")
      expect(last_journal.details["observed_in_versions_#{version1.id}"]).to eq([nil, "Sprint 1"])
    end

    it "creates a journal entry when a version is removed" do
      update_wp(observed_in_version_ids: [version1.id])
      work_package.reload

      expect do
        update_wp(observed_in_version_ids: [])
      end.to change(Journal, :count).by(1)

      last_journal = work_package.journals.last
      expect(last_journal.details).to have_key("observed_in_versions_#{version1.id}")
      expect(last_journal.details["observed_in_versions_#{version1.id}"]).to eq(["Sprint 1", nil])
    end

    it "does not create a new journal when observed_in_versions are unchanged" do
      update_wp(observed_in_version_ids: [version1.id])
      work_package.reload

      expect do
        update_wp(observed_in_version_ids: [version1.id])
      end.not_to change(Journal, :count)
    end
  end
end
