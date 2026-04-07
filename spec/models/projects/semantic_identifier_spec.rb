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

RSpec.describe Projects::SemanticIdentifier, with_settings: { work_packages_identifier: "semantic" } do
  describe "#allocate_wp_semantic_identifier!" do
    let(:project) { create(:project, identifier: "PROJ", wp_sequence_counter: 0) }

    it "returns the allocated sequence number and semantic identifier" do
      seq, identifier = project.allocate_wp_semantic_identifier!
      expect(seq).to eq(1)
      expect(identifier).to eq("PROJ-1")
    end

    it "increments the counter on each successive call" do
      project.allocate_wp_semantic_identifier!
      seq, identifier = project.allocate_wp_semantic_identifier!
      expect(seq).to eq(2)
      expect(identifier).to eq("PROJ-2")
    end

    it "persists the updated counter to the database" do
      project.allocate_wp_semantic_identifier!
      expect(project.reload.wp_sequence_counter).to eq(1)
    end

    it "uses the current project identifier as the prefix" do
      project.update_columns(identifier: "NEWPROJ")
      _, identifier = project.allocate_wp_semantic_identifier!
      expect(identifier).to eq("NEWPROJ-1")
    end
  end

  describe "#handle_semantic_rename" do
    let(:project) { create(:project, identifier: "PROJ", wp_sequence_counter: 0) }
    let(:target_project) { create(:project, identifier: "OTHER", wp_sequence_counter: 0) }
    let(:wp1) { create(:work_package, project:) }
    let(:wp2) { create(:work_package, project:) }

    before do
      wp1
      wp2
      project.update_columns(identifier: "NEWPROJ")
    end

    it "preserves old-prefix aliases for resident WPs" do
      project.handle_semantic_rename("PROJ")
      expect(WorkPackageSemanticAlias.find_by(identifier: "PROJ-1")).to be_present
      expect(WorkPackageSemanticAlias.find_by(identifier: "PROJ-2")).to be_present
    end

    it "adds new-prefix aliases for resident WPs" do
      project.handle_semantic_rename("PROJ")
      expect(WorkPackageSemanticAlias.find_by(identifier: "NEWPROJ-1")).to be_present
      expect(WorkPackageSemanticAlias.find_by(identifier: "NEWPROJ-2")).to be_present
    end

    it "updates identifier on resident WPs to the new prefix" do
      project.handle_semantic_rename("PROJ")
      expect(wp1.reload.identifier).to eq("NEWPROJ-1")
      expect(wp2.reload.identifier).to eq("NEWPROJ-2")
    end

    it "is idempotent (safe to run twice)" do
      project.handle_semantic_rename("PROJ")
      expect { project.handle_semantic_rename("PROJ") }.not_to raise_error
    end

    context "when records span multiple batches" do
      let(:wp3) { create(:work_package, project:) }

      before { wp3 }

      it "processes all aliases across batch boundaries" do
        project.handle_semantic_rename("PROJ", batch_size: 2)
        expect(WorkPackageSemanticAlias.find_by(identifier: "NEWPROJ-1")).to be_present
        expect(WorkPackageSemanticAlias.find_by(identifier: "NEWPROJ-2")).to be_present
        expect(WorkPackageSemanticAlias.find_by(identifier: "NEWPROJ-3")).to be_present
      end

      it "rewrites all WP identifiers across batch boundaries" do
        project.handle_semantic_rename("PROJ", batch_size: 2)
        expect(wp1.reload.identifier).to eq("NEWPROJ-1")
        expect(wp2.reload.identifier).to eq("NEWPROJ-2")
        expect(wp3.reload.identifier).to eq("NEWPROJ-3")
      end
    end

    context "when a WP has previously moved out of the project" do
      before do
        # Move wp1 to OTHER properly so "PROJ-1" ends up as an alias
        wp1.update_columns(project_id: target_project.id)
        wp1.allocate_and_register_semantic_id
      end

      it "appends a new-prefix alias derived from the old alias row" do
        project.handle_semantic_rename("PROJ")
        expect(WorkPackageSemanticAlias.find_by(identifier: "NEWPROJ-1")).to be_present
      end

      it "preserves the original old-prefix alias" do
        project.handle_semantic_rename("PROJ")
        expect(WorkPackageSemanticAlias.find_by(identifier: "PROJ-1")).to be_present
      end

      it "does not update identifier on the moved-away WP" do
        project.handle_semantic_rename("PROJ")
        expect(wp1.reload.identifier).to eq("OTHER-1")
      end
    end
  end
end
