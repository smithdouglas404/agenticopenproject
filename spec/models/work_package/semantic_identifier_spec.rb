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

RSpec.describe WorkPackage::SemanticIdentifier do
  let(:project) { create(:project, identifier: "MYPROJ") }
  # Creating a WP in alphanumeric mode auto-registers it: gets sequence_number 1 and entry "MYPROJ-1".
  let(:work_package) { create(:work_package, project:) }

  before do
    allow(Setting::WorkPackageIdentifier).to receive_messages(semantic?: true, classic?: false)
    work_package
  end

  describe "after_create registration" do
    it "assigns a sequence number" do
      expect(work_package.reload.sequence_number).to eq(1)
    end

    it "sets identifier on the work package" do
      expect(work_package.reload.identifier).to eq("MYPROJ-1")
    end

    it "creates a registry entry for the initial identifier" do
      expect(work_package.semantic_aliases.pluck(:identifier)).to contain_exactly("MYPROJ-1")
    end

    it "increments the counter for each successive WP" do
      wp2 = create(:work_package, project:)
      expect(wp2.reload.sequence_number).to eq(2)
      expect(wp2.reload.identifier).to eq("MYPROJ-2")
    end
  end

  describe "WorkPackage.find_by_id_or_identifier" do
    context "with a numeric param" do
      it "finds by primary key" do
        expect(WorkPackage.find_by_id_or_identifier(work_package.id.to_s)).to eq(work_package)
      end

      it "returns nil for unknown id" do
        expect(WorkPackage.find_by_id_or_identifier("9999999")).to be_nil
      end
    end

    context "with a semantic param" do
      context "when the identifier matches work_packages.identifier (fast path)" do
        it "finds directly via identifier without hitting the alias table" do
          expect(WorkPackage.find_by_id_or_identifier("MYPROJ-1")).to eq(work_package)
        end

        it "returns nil when no WP has that identifier and no alias or fallback matches" do
          expect(WorkPackage.find_by_id_or_identifier("MYPROJ-999")).to be_nil
        end
      end

      context "when the identifier is a historic alias (alias table path)" do
        it "resolves historic entries via the alias registry" do
          WorkPackageSemanticAlias.create!(identifier: "OLDPROJ-1", work_package:)
          expect(WorkPackage.find_by_id_or_identifier("OLDPROJ-1")).to eq(work_package)
        end

        it "resolves when identifier differs but an alias row exists" do
          work_package.update_columns(identifier: "OTHER-99")
          expect(WorkPackage.find_by_id_or_identifier("MYPROJ-1")).to eq(work_package)
        end
      end

      it "returns nil for unknown sequence" do
        expect(WorkPackage.find_by_id_or_identifier("MYPROJ-999")).to be_nil
      end

      it "returns nil for unknown project prefix" do
        expect(WorkPackage.find_by_id_or_identifier("NOPE-1")).to be_nil
      end

      it "returns nil for an unparseable string" do
        expect(WorkPackage.find_by_id_or_identifier("not-an-identifier!")).to be_nil
      end
    end

    context "with visibility scoping" do
      let(:member_user) { create(:user, member_with_permissions: { project => [:view_work_packages] }) }
      let(:non_member_user) { create(:user) }

      it "returns the WP for a user who can see it" do
        expect(WorkPackage.visible(member_user).find_by_id_or_identifier("MYPROJ-1")).to eq(work_package)
      end

      it "returns nil for a user who cannot see it" do
        expect(WorkPackage.visible(non_member_user).find_by_id_or_identifier("MYPROJ-1")).to be_nil
      end

      it "also scopes numeric lookup" do
        expect(WorkPackage.visible(non_member_user).find_by_id_or_identifier(work_package.id.to_s)).to be_nil
      end
    end
  end

  describe "WorkPackage.find_by_id_or_identifier!" do
    it "returns the work package when found" do
      expect(WorkPackage.find_by_id_or_identifier!(work_package.id.to_s)).to eq(work_package)
    end

    it "raises ActiveRecord::RecordNotFound when not found" do
      expect { WorkPackage.find_by_id_or_identifier!("MYPROJ-999") }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "#display_id" do
    context "when semantic mode is active",
            with_flag: { semantic_work_package_ids: true },
            with_settings: { work_packages_identifier: "semantic" } do
      it "returns the semantic identifier" do
        expect(work_package.display_id).to eq("MYPROJ-1")
      end
    end

    context "when semantic mode is not active",
            with_flag: { semantic_work_package_ids: false } do
      it "returns the numeric id" do
        expect(work_package.display_id).to eq(work_package.id)
      end
    end
  end

  describe "#allocate_and_register_semantic_id" do
    let(:project) { create(:project, identifier: "PROJ", wp_sequence_counter: 0) }
    let(:target_project) { create(:project, identifier: "OTHER", wp_sequence_counter: 0) }

    before do
      work_package.update_columns(project_id: target_project.id)
    end

    it "preserves the old identifier as a historical alias (written at creation)" do
      work_package.allocate_and_register_semantic_id
      expect(WorkPackageSemanticAlias.find_by(identifier: "PROJ-1")).to be_present
    end

    it "updates sequence_number and identifier to the target project's values" do
      work_package.allocate_and_register_semantic_id
      expect(work_package.reload.sequence_number).to eq(1)
      expect(work_package.reload.identifier).to eq("OTHER-1")
    end

    it "adds the new identifier to the alias table" do
      work_package.allocate_and_register_semantic_id
      expect(WorkPackageSemanticAlias.find_by(identifier: "OTHER-1")).to be_present
    end
  end
end
