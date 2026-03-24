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

RSpec.describe WorkPackages::Identifier do
  let(:project) { create(:project, identifier: "sc") }

  describe "database indexes" do
    subject { WorkPackage.new }

    it { is_expected.to have_db_index(%i[project_id sequence_number]).unique(true) }
    it { is_expected.to have_db_index(:identifier).unique(true) }
  end

  describe "FriendlyId configuration" do
    it "uses the identifier column as the FriendlyId slug" do
      config = WorkPackage.friendly_id_config
      expect(config.slug_column).to eq(:identifier)
    end

    it "includes the finders module" do
      expect(WorkPackage.respond_to?(:friendly)).to be true
    end
  end

  describe "finding by identifier" do
    let!(:work_package) do
      wp = create(:work_package, project:)
      wp.update!(identifier: "SC-1", sequence_number: 1)
      wp
    end

    it "finds by semantic identifier via .friendly.find" do
      expect(WorkPackage.friendly.find("SC-1")).to eq(work_package)
    end

    it "finds by semantic identifier via .find (FriendlyId proxies it)" do
      expect(WorkPackage.find("SC-1")).to eq(work_package)
    end

    it "finds by numeric ID (integer)" do
      expect(WorkPackage.friendly.find(work_package.id)).to eq(work_package)
    end

    it "finds by numeric ID (string)" do
      expect(WorkPackage.friendly.find(work_package.id.to_s)).to eq(work_package)
    end

    it "raises RecordNotFound for a non-existent identifier" do
      expect { WorkPackage.friendly.find("NONEXISTENT-999") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises RecordNotFound for a non-existent numeric ID" do
      expect { WorkPackage.friendly.find(0) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "still finds a work package without an identifier by its numeric ID" do
      wp_without_identifier = create(:work_package, project:)

      expect(WorkPackage.find(wp_without_identifier.id)).to eq(wp_without_identifier)
    end
  end

  describe "identifier uniqueness" do
    let!(:work_package) do
      wp = create(:work_package, project:)
      wp.update!(identifier: "SC-1", sequence_number: 1)
      wp
    end

    it "enforces uniqueness at the database level" do
      other_wp = create(:work_package, project:)

      expect do
        other_wp.update_columns(identifier: "SC-1")
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows nil identifiers (WPs created before feature is enabled)" do
      wp1 = create(:work_package, project:)
      wp2 = create(:work_package, project:)

      # Both have nil identifiers — no unique constraint violation
      expect(wp1.identifier).to be_nil
      expect(wp2.identifier).to be_nil
    end
  end

  describe "historical identifier resolution" do
    let!(:work_package) do
      wp = create(:work_package, project:)
      wp.update!(identifier: "SC-1", sequence_number: 1)
      wp
    end

    it "records the old identifier in friendly_id_slugs when identifier changes" do
      work_package.update!(identifier: "INFRA-42")

      expect(FriendlyId::Slug.where(slug: "SC-1", sluggable_type: "WorkPackage")).to exist
    end

    it "finds a work package by a previous identifier" do
      work_package.update!(identifier: "INFRA-42")

      expect(WorkPackage.friendly.find("SC-1")).to eq(work_package)
    end

    it "finds a work package by its current identifier after a change" do
      work_package.update!(identifier: "INFRA-42")

      expect(WorkPackage.friendly.find("INFRA-42")).to eq(work_package)
    end

    it "resolves the latest work package when multiple identifiers have been used" do
      work_package.update!(identifier: "INFRA-42")
      work_package.update!(identifier: "DEV-7")

      # All three identifiers resolve to the same work package
      expect(WorkPackage.friendly.find("SC-1")).to eq(work_package)
      expect(WorkPackage.friendly.find("INFRA-42")).to eq(work_package)
      expect(WorkPackage.friendly.find("DEV-7")).to eq(work_package)
    end

    it "accumulates slug history entries for each identifier change" do
      work_package.update!(identifier: "INFRA-42")
      work_package.update!(identifier: "DEV-7")

      slugs = FriendlyId::Slug.where(sluggable_id: work_package.id, sluggable_type: "WorkPackage").pluck(:slug)
      # FriendlyId records a slug for each value (including the current one)
      expect(slugs).to include("SC-1", "INFRA-42")
    end

    it "cleans up all slug history when work package is destroyed" do
      work_package.update!(identifier: "INFRA-42")

      slug_count = FriendlyId::Slug.where(
        sluggable_id: work_package.id, sluggable_type: "WorkPackage"
      ).count
      expect(slug_count).to be >= 1

      expect do
        work_package.destroy!
      end.to change {
        FriendlyId::Slug.where(sluggable_id: work_package.id, sluggable_type: "WorkPackage").count
      }.to(0)
    end
  end

  describe "has_many :historical_work_package_identifiers" do
    let!(:work_package) { create(:work_package, project:) }

    it "associates with historical records" do
      record = HistoricalWorkPackageIdentifier.create!(
        project:, work_package:, sequence_number: 1
      )

      expect(work_package.historical_work_package_identifiers).to include(record)
    end

    it "can have multiple records across different projects (move scenario)" do
      target_project = create(:project, identifier: "infra")

      rec1 = HistoricalWorkPackageIdentifier.create!(project:, work_package:, sequence_number: 5)
      rec2 = HistoricalWorkPackageIdentifier.create!(project: target_project, work_package:, sequence_number: 1)

      expect(work_package.historical_work_package_identifiers).to contain_exactly(rec1, rec2)
    end

    it "destroys historical records when work package is destroyed" do
      HistoricalWorkPackageIdentifier.create!(
        project:, work_package:, sequence_number: 1
      )

      expect { work_package.destroy! }
        .to change(HistoricalWorkPackageIdentifier, :count).by(-1)
    end
  end

  describe "unset_slug_if_invalid override" do
    it "does not revert the identifier when validation fails" do
      wp = create(:work_package, project:)
      wp.update!(identifier: "SC-1", sequence_number: 1)

      # Force a validation failure on another attribute
      wp.subject = ""
      wp.valid?

      # Identifier should NOT be reverted to nil by FriendlyId
      expect(wp.identifier).to eq("SC-1")
    end
  end
end
