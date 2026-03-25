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

RSpec.describe WorkPackages::Identifier::FinderMethods do
  let(:project) { create(:project, identifier: "sc") }

  let!(:work_package) do
    wp = create(:work_package, project:)
    wp.update_columns(identifier: "sc-1", sequence_number: 1)
    wp
  end

  # Simulates a project rename: records the old identifier as a slug,
  # updates the project identifier, and refreshes work package identifiers.
  def rename_project!(old_identifier, new_identifier)
    FriendlyId::Slug.create!(slug: old_identifier, sluggable: project, sluggable_type: "Project")
    project.update_column(:identifier, new_identifier)
    project.work_packages.where.not(sequence_number: nil).update_all(
      ["identifier = ? || '-' || CAST(sequence_number AS text)", new_identifier]
    )
  end

  shared_examples "resolves to the expected work package" do
    it "via .find" do
      expect(WorkPackage.find(identifier)).to eq(expected_wp)
    end

    it "via .friendly.find" do
      expect(WorkPackage.friendly.find(identifier)).to eq(expected_wp)
    end

    it "via .find_by_friendly_id" do
      expect(WorkPackage.friendly.find_by_friendly_id(identifier)).to eq(expected_wp) # rubocop:disable Rails/DynamicFindBy
    end

    it "via .exists?" do
      expect(WorkPackage.exists?(identifier)).to be true
    end
  end

  shared_examples "raises RecordNotFound" do
    it "via .find" do
      expect { WorkPackage.find(identifier) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "via .friendly.find" do
      expect { WorkPackage.friendly.find(identifier) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "via .find_by_friendly_id" do
      expect { WorkPackage.friendly.find_by_friendly_id(identifier) }.to raise_error(ActiveRecord::RecordNotFound) # rubocop:disable Rails/DynamicFindBy
    end

    it "via .exists?" do
      expect(WorkPackage.exists?(identifier)).to be false
    end
  end

  describe "current identifier lookup" do
    let(:identifier) { "sc-1" }
    let(:expected_wp) { work_package }

    include_examples "resolves to the expected work package"
  end

  describe "ghost identifier after single rename" do
    let!(:new_wp) do
      rename_project!("sc", "infra")
      wp = create(:work_package, project:)
      wp.update_columns(identifier: "infra-2", sequence_number: 2)
      wp
    end

    context "with the ghost identifier (old prefix + new sequence)" do
      let(:identifier) { "sc-2" }
      let(:expected_wp) { new_wp }

      include_examples "resolves to the expected work package"
    end

    context "with the current identifier" do
      let(:identifier) { "infra-2" }
      let(:expected_wp) { new_wp }

      include_examples "resolves to the expected work package"
    end

    context "with an old identifier recorded in slug history" do
      before do
        FriendlyId::Slug.create!(slug: "sc-1", sluggable: work_package, sluggable_type: "WorkPackage")
      end

      let(:identifier) { "sc-1" }
      let(:expected_wp) { work_package }

      include_examples "resolves to the expected work package"
    end
  end

  describe "ghost identifier after multiple renames" do
    before do
      rename_project!("sc", "infra")
      rename_project!("infra", "platform")
    end

    context "with the earliest historical prefix" do
      let(:identifier) { "sc-1" }
      let(:expected_wp) { work_package }

      include_examples "resolves to the expected work package"
    end

    context "with an intermediate historical prefix" do
      let(:identifier) { "infra-1" }
      let(:expected_wp) { work_package }

      include_examples "resolves to the expected work package"
    end

    context "with the current prefix" do
      let(:identifier) { "platform-1" }
      let(:expected_wp) { work_package }

      include_examples "resolves to the expected work package"
    end
  end

  describe "invalid identifiers" do
    context "with a non-existent project prefix" do
      let(:identifier) { "nonexistent-1" }

      include_examples "raises RecordNotFound"
    end

    context "with a valid prefix but non-existent sequence number" do
      let(:identifier) { "sc-999" }

      include_examples "raises RecordNotFound"
    end

    context "with a malformed identifier (no sequence)" do
      let(:identifier) { "sc" }

      include_examples "raises RecordNotFound"
    end
  end

  describe "numeric ID fallback" do
    it "still resolves by numeric primary key" do
      expect(WorkPackage.find(work_package.id)).to eq(work_package)
    end

    it "still resolves by numeric primary key as string" do
      expect(WorkPackage.find(work_package.id.to_s)).to eq(work_package)
    end
  end
end
