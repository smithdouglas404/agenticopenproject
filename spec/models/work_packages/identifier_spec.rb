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

  describe "FinderMethods wiring" do
    it "extends the model class with FinderMethods" do
      expect(WorkPackage.singleton_class.ancestors).to include(WorkPackages::Identifier::FinderMethods)
    end

    it "includes FinderMethods in the relation class" do
      expect(WorkPackage.all.class.ancestors).to include(WorkPackages::Identifier::FinderMethods)
    end
  end

  describe "finding by identifier" do
    let!(:work_package) do
      wp = create(:work_package, project:)
      wp.update_columns(identifier: "sc-1", sequence_number: 1)
      wp
    end

    it "finds by semantic identifier via .find" do
      expect(WorkPackage.find("sc-1")).to eq(work_package)
    end

    it "finds by numeric ID (integer)" do
      expect(WorkPackage.find(work_package.id)).to eq(work_package)
    end

    it "finds by numeric ID (string)" do
      expect(WorkPackage.find(work_package.id.to_s)).to eq(work_package)
    end

    it "raises RecordNotFound for a non-existent identifier" do
      expect { WorkPackage.find("NONEXISTENT-999") }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises RecordNotFound for a non-existent numeric ID" do
      expect { WorkPackage.find(0) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "still finds a work package without an identifier by its numeric ID" do
      wp_without_identifier = create(:work_package, project:)

      expect(WorkPackage.find(wp_without_identifier.id)).to eq(wp_without_identifier)
    end
  end

  describe ".identified scope" do
    let!(:identified_wp) do
      wp = create(:work_package, project:)
      wp.update_columns(identifier: "sc-1", sequence_number: 1)
      wp
    end

    let!(:unidentified_wp) { create(:work_package, project:) }

    it "includes work packages with both identifier and sequence_number" do
      expect(WorkPackage.identified).to include(identified_wp)
    end

    it "excludes work packages without identifiers" do
      expect(WorkPackage.identified).not_to include(unidentified_wp)
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

  describe "identifier stability on validation failure" do
    it "does not revert the identifier when validation fails" do
      wp = create(:work_package, project:)
      wp.update!(identifier: "SC-1", sequence_number: 1)

      # Force a validation failure on another attribute
      wp.subject = ""
      wp.valid?

      # Identifier should remain stable across validation failures
      expect(wp.identifier).to eq("SC-1")
    end
  end
end
