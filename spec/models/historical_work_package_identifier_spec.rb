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

RSpec.describe HistoricalWorkPackageIdentifier do
  let(:project) { create(:project) }
  let(:work_package) { create(:work_package, project:) }

  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:work_package) }
    it { is_expected.to belong_to(:friendly_id_slug).optional }
  end

  describe "validations" do
    subject { described_class.new(project:, work_package:, sequence_number: 1) }

    it { is_expected.to validate_presence_of(:sequence_number) }
    it { is_expected.to validate_numericality_of(:sequence_number).only_integer.is_greater_than(0) }
    it { is_expected.to validate_uniqueness_of(:sequence_number).scoped_to(:project_id) }
  end

  describe "database indexes" do
    subject { described_class.new }

    it { is_expected.to have_db_index(%i[project_id sequence_number]).unique(true) }
    it { is_expected.to have_db_index(:work_package_id) }
  end

  describe "sequence reservation" do
    it "prevents duplicate sequence numbers within the same project" do
      described_class.create!(project:, work_package:, sequence_number: 1)
      other_wp = create(:work_package, project:)

      record = described_class.new(project:, work_package: other_wp, sequence_number: 1)
      expect(record).not_to be_valid
      expect(record.errors[:sequence_number]).to include("has already been taken.")
    end

    it "allows the same sequence number in different projects" do
      other_project = create(:project)
      other_wp = create(:work_package, project: other_project)

      described_class.create!(project:, work_package:, sequence_number: 1)

      expect do
        described_class.create!(project: other_project, work_package: other_wp, sequence_number: 1)
      end.not_to raise_error
    end

    it "survives work package moves — old row stays for reservation" do
      described_class.create!(project:, work_package:, sequence_number: 5)
      target_project = create(:project)

      # WP moves to target project — new row
      described_class.create!(project: target_project, work_package:, sequence_number: 1)

      # Original reservation still exists
      expect(described_class.where(project:, sequence_number: 5)).to exist

      # MAX still accounts for the reserved sequence
      max_seq = described_class.where(project_id: project.id).maximum(:sequence_number)
      expect(max_seq).to eq(5)
    end
  end

  describe "friendly_id_slug linkage" do
    it "can link to a FriendlyId::Slug entry for traceability" do
      slug = FriendlyId::Slug.create!(
        slug: "SC-1",
        sluggable_id: work_package.id,
        sluggable_type: "WorkPackage"
      )

      record = described_class.create!(
        project:, work_package:, sequence_number: 1, friendly_id_slug: slug
      )

      expect(record.friendly_id_slug).to eq(slug)
      expect(record.friendly_id_slug.slug).to eq("SC-1")
    end

    it "allows nil friendly_id_slug for current assignments" do
      record = described_class.create!(
        project:, work_package:, sequence_number: 1, friendly_id_slug: nil
      )

      expect(record).to be_valid
      expect(record.friendly_id_slug).to be_nil
    end
  end

  describe "MAX(sequence_number) for allocation" do
    it "returns the correct high-water mark for a project" do
      wp1 = create(:work_package, project:)
      wp2 = create(:work_package, project:)
      wp3 = create(:work_package, project:)

      described_class.create!(project:, work_package: wp1, sequence_number: 1)
      described_class.create!(project:, work_package: wp2, sequence_number: 2)
      described_class.create!(project:, work_package: wp3, sequence_number: 3)

      max = described_class.where(project_id: project.id).maximum(:sequence_number)
      expect(max).to eq(3)
    end

    it "accounts for gaps left by moved work packages" do
      wp1 = create(:work_package, project:)
      wp2 = create(:work_package, project:)
      target = create(:project)

      # wp1 gets sequence 1, wp2 gets sequence 2
      described_class.create!(project:, work_package: wp1, sequence_number: 1)
      described_class.create!(project:, work_package: wp2, sequence_number: 2)

      # wp2 moves to target project — old reservation stays
      described_class.create!(project: target, work_package: wp2, sequence_number: 1)

      # MAX for source project still returns 2 (not 1)
      max = described_class.where(project_id: project.id).maximum(:sequence_number)
      expect(max).to eq(2)
    end

    it "returns nil for a project with no work packages" do
      empty_project = create(:project)

      max = described_class.where(project_id: empty_project.id).maximum(:sequence_number)
      expect(max).to be_nil
    end
  end

  describe "database constraints" do
    it "enforces the unique index at the database level" do
      described_class.create!(project:, work_package:, sequence_number: 1)
      other_wp = create(:work_package, project:)

      expect do
        # Bypass validations to test the DB constraint directly
        described_class.new(project:, work_package: other_wp, sequence_number: 1)
                       .save(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces foreign key on project" do
      expect do
        described_class.create!(project_id: 0, work_package:, sequence_number: 1)
      end.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it "enforces foreign key on work_package" do
      expect do
        described_class.create!(project:, work_package_id: 0, sequence_number: 1)
      end.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end
end
