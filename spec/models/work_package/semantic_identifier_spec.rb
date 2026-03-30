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
    allow(Setting::WorkPackageIdentifier).to receive_messages(alphanumeric?: true, numeric?: false)
    work_package
  end

  describe "after_create registration" do
    it "assigns a sequence number" do
      expect(work_package.reload.sequence_number).to eq(1)
    end

    it "sets semantic_id on the work package" do
      expect(work_package.reload.semantic_id).to eq("MYPROJ-1")
    end

    it "does not create a registry entry (initial identifier is current, not historical)" do
      expect(work_package.semantic_aliases).to be_empty
    end

    it "increments the counter for each successive WP" do
      wp2 = create(:work_package, project:)
      expect(wp2.reload.sequence_number).to eq(2)
      expect(wp2.reload.semantic_id).to eq("MYPROJ-2")
    end
  end

  describe "WorkPackage.find_by_identifier" do
    context "with a numeric param" do
      it "finds by primary key" do
        expect(WorkPackage.find_by_identifier(work_package.id.to_s)).to eq(work_package)
      end

      it "returns nil for unknown id" do
        expect(WorkPackage.find_by_identifier("9999999")).to be_nil
      end
    end

    context "with a semantic param" do
      context "when the identifier matches work_packages.semantic_id (fast path)" do
        it "finds directly via semantic_id without hitting the alias table" do
          expect(WorkPackage.find_by_identifier("MYPROJ-1")).to eq(work_package)
        end

        it "returns nil when no WP has that semantic_id and no alias or fallback matches" do
          expect(WorkPackage.find_by_identifier("MYPROJ-999")).to be_nil
        end
      end

      context "when the identifier is a historic alias (alias table path)" do
        it "resolves historic entries via the alias registry" do
          WorkPackageSemanticAlias.create!(identifier: "OLDPROJ-1", work_package:)
          expect(WorkPackage.find_by_identifier("OLDPROJ-1")).to eq(work_package)
        end

        it "resolves when semantic_id differs but an alias row exists" do
          work_package.update_columns(semantic_id: "OTHER-99")
          expect(WorkPackage.find_by_identifier("MYPROJ-1")).to eq(work_package)
        end
      end

      context "when the identifier is not in the registry (computed fallback)" do
        before do
          work_package.semantic_aliases.delete_all
        end

        it "resolves via project identifier + sequence_number" do
          expect(WorkPackage.find_by_identifier("MYPROJ-1")).to eq(work_package)
        end

        it "returns nil for unknown sequence" do
          expect(WorkPackage.find_by_identifier("MYPROJ-999")).to be_nil
        end

        it "returns nil for unknown project prefix" do
          expect(WorkPackage.find_by_identifier("NOPE-1")).to be_nil
        end
      end

      it "returns nil for an unparseable string" do
        expect(WorkPackage.find_by_identifier("not-an-identifier!")).to be_nil
      end
    end

    context "with visibility scoping" do
      let(:member_user) { create(:user, member_with_permissions: { project => [:view_work_packages] }) }
      let(:non_member_user) { create(:user) }

      it "returns the WP for a user who can see it" do
        expect(WorkPackage.visible(member_user).find_by_identifier("MYPROJ-1")).to eq(work_package)
      end

      it "returns nil for a user who cannot see it" do
        expect(WorkPackage.visible(non_member_user).find_by_identifier("MYPROJ-1")).to be_nil
      end

      it "also scopes numeric lookup" do
        expect(WorkPackage.visible(non_member_user).find_by_identifier(work_package.id.to_s)).to be_nil
      end
    end
  end

  describe "WorkPackage.find_by_identifier!" do
    it "returns the work package when found" do
      expect(WorkPackage.find_by_identifier!(work_package.id.to_s)).to eq(work_package)
    end

    it "raises ActiveRecord::RecordNotFound when not found" do
      expect { WorkPackage.find_by_identifier!("MYPROJ-999") }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "WorkPackage.register_move" do
    let(:project) { create(:project, identifier: "PROJ", wp_sequence_counter: 0) }
    let(:target_project) { create(:project, identifier: "OTHER", wp_sequence_counter: 0) }

    before do
      work_package.update_columns(project_id: target_project.id)
    end

    it "retires the old identifier as a historical alias" do
      WorkPackage.handle_wp_move(work_package)
      expect(WorkPackageSemanticAlias.find_by(identifier: "PROJ-1")).to be_present
    end

    it "updates sequence_number and semantic_id to the target project's values" do
      WorkPackage.handle_wp_move(work_package)
      expect(work_package.reload.sequence_number).to eq(1)
      expect(work_package.reload.semantic_id).to eq("OTHER-1")
    end

    it "does not add the new identifier to the alias table" do
      WorkPackage.handle_wp_move(work_package)
      expect(WorkPackageSemanticAlias.find_by(identifier: "OTHER-1")).to be_nil
    end
  end

  describe "WorkPackage.register_project_rename" do
    let(:project) { create(:project, identifier: "PROJ", wp_sequence_counter: 0) }
    let(:target_project) { create(:project, identifier: "OTHER", wp_sequence_counter: 0) }
    let(:work_package) { nil } # suppress outer eager instantiation so wp1/wp2 start at sequence 1
    let(:wp1) { create(:work_package, project:) }
    let(:wp2) { create(:work_package, project:) }

    before do
      wp1
      wp2
      project.update_columns(identifier: "NEWPROJ")
    end

    it "inserts pre-rename identifiers as historical aliases for resident WPs" do
      WorkPackage.handle_project_rename(project, "PROJ")
      expect(WorkPackageSemanticAlias.find_by(identifier: "PROJ-1")).to be_present
      expect(WorkPackageSemanticAlias.find_by(identifier: "PROJ-2")).to be_present
    end

    it "does not add new-prefix entries to the alias table" do
      WorkPackage.handle_project_rename(project, "PROJ")
      expect(WorkPackageSemanticAlias.find_by(identifier: "NEWPROJ-1")).to be_nil
      expect(WorkPackageSemanticAlias.find_by(identifier: "NEWPROJ-2")).to be_nil
    end

    it "updates semantic_id on resident WPs to the new prefix" do
      WorkPackage.handle_project_rename(project, "PROJ")
      expect(wp1.reload.semantic_id).to eq("NEWPROJ-1")
      expect(wp2.reload.semantic_id).to eq("NEWPROJ-2")
    end

    it "is idempotent (safe to run twice)" do
      WorkPackage.handle_project_rename(project, "PROJ")
      expect { WorkPackage.handle_project_rename(project, "PROJ") }.not_to raise_error
    end

    context "when a WP has previously moved out of the project" do
      before do
        # Move wp1 to OTHER properly so "PROJ-1" ends up as an alias
        wp1.update_columns(project_id: target_project.id)
        WorkPackage.handle_wp_move(wp1)
      end

      it "appends a new-prefix alias derived from the old alias row" do
        WorkPackage.handle_project_rename(project, "PROJ")
        expect(WorkPackageSemanticAlias.find_by(identifier: "NEWPROJ-1")).to be_present
      end

      it "preserves the original old-prefix alias" do
        WorkPackage.handle_project_rename(project, "PROJ")
        expect(WorkPackageSemanticAlias.find_by(identifier: "PROJ-1")).to be_present
      end

      it "does not update semantic_id on the moved-away WP" do
        WorkPackage.handle_project_rename(project, "PROJ")
        expect(wp1.reload.semantic_id).to eq("OTHER-1")
      end
    end
  end
end
