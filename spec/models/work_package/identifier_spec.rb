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

RSpec.describe WorkPackage::Identifier do
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

    it "creates a current registry entry" do
      entry = work_package.current_semantic_id
      expect(entry.identifier).to eq("MYPROJ-1")
      expect(entry.current).to be(true)
    end

    it "increments the counter for each successive WP" do
      wp2 = create(:work_package, project:)
      expect(wp2.reload.sequence_number).to eq(2)
      expect(wp2.current_semantic_id.identifier).to eq("MYPROJ-2")
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
      context "when the identifier is in the registry" do
        it "finds via the current registry entry" do
          expect(WorkPackage.find_by_identifier("MYPROJ-1")).to eq(work_package)
        end

        it "also resolves historic (current: false) entries" do
          work_package.semantic_ids.update_all(current: false)
          WorkPackageSemanticId.create!(identifier: "OLDPROJ-1", work_package:, current: false)
          expect(WorkPackage.find_by_identifier("OLDPROJ-1")).to eq(work_package)
        end
      end

      context "when the identifier is not in the registry (computed fallback)" do
        before do
          work_package.semantic_ids.delete_all
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
        expect(WorkPackage.find_by_identifier("MYPROJ-1", user: member_user)).to eq(work_package)
      end

      it "returns nil for a user who cannot see it" do
        expect(WorkPackage.find_by_identifier("MYPROJ-1", user: non_member_user)).to be_nil
      end

      it "also scopes numeric lookup" do
        expect(WorkPackage.find_by_identifier(work_package.id.to_s, user: non_member_user)).to be_nil
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
end
