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

RSpec.describe Projects::IdentifierFinder do
  let!(:project) { create(:project, name: "My Project", identifier: "my") }
  let!(:project_former_identifier) { create(:project_former_identifier, project:, identifier: "old-my") }
  let!(:other_project) { create(:project, name: "Other Project", identifier: "other") }
  let!(:other_project_former_identifier) { create(:project_former_identifier, project: other_project, identifier: "old-other") }

  describe ".enhanced_find" do
    describe "with a string" do
      it "finds by identifier of the project" do
        expect(Project.enhanced_find("my")).to eq(project)
        expect(Project.enhanced_find("other")).to eq(other_project)
      end

      it "finds by former identifier of the project" do
        expect(Project.enhanced_find("old-my")).to eq(project)
        expect(Project.enhanced_find("old-other")).to eq(other_project)
      end

      it "raises if not found and nil is not allowed" do
        expect { Project.enhanced_find("unknown") }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "does not raise if not found and nil is allowed" do
        expect(Project.enhanced_find("unknown", allow_nil: true)).to be_nil
      end

      it "finds by identifier when used with a scope" do
        expect(Project.active.enhanced_find("my")).to eq(project)
      end

      it "finds by former identifier when used with a scope" do
        expect(Project.active.enhanced_find("old-my")).to eq(project)
      end

      it "finds by identifier when used with an association" do
        user = create(:user)
        create(:member, project:, principal: user, roles: [create(:project_role)])
        expect(user.projects.enhanced_find("my")).to eq(project)
      end

      it "finds by former identifier when used with an association" do
        user = create(:user)
        create(:member, project:, principal: user, roles: [create(:project_role)])
        expect(user.projects.enhanced_find("old-my")).to eq(project)
      end
    end

    describe "with numbers" do
      let(:unknown_id) { other_project.id + 1 }

      it "finds by ID" do
        expect(Project.enhanced_find(project.id)).to eq(project)
        expect(Project.enhanced_find(other_project.id)).to eq(other_project)
      end

      it "finds by multiple IDs" do
        expect(Project.enhanced_find(project.id, other_project.id)).to eq([project, other_project])
      end

      it "finds by ID when used with a scope" do
        expect(Project.active.enhanced_find(project.id)).to eq(project)
      end

      it "finds by ID when used with an association" do
        user = create(:user)
        create(:member, project:, principal: user, roles: [create(:project_role)])
        expect(user.projects.enhanced_find(project.id)).to eq(project)
      end

      it "raises if not found and nil is not allowed" do
        expect { Project.enhanced_find(unknown_id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      # TODO - this uses super and raises
      # it "does not raise if not found and nil is allowed" do
      #   expect(Project.enhanced_find(unknown_id, allow_nil: true)).to be_nil
      # end
    end

    describe "with other data types" do
      it "finds by an array of IDs" do
        expect(Project.enhanced_find([project.id, other_project.id])).to eq([project, other_project])
      end
    end
  end

  describe "internal helper methods" do
    let(:tester) { Object.new.tap { |obj| obj.extend(described_class) } }

    describe ".semantic_id?" do
      context "with string inputs that are not just integers" do
        it "returns true for string 'my-project'" do
          expect(tester.send(:semantic_id?, "my-project")).to be true
        end

        it "returns true for string 'project-123'" do
          expect(tester.send(:semantic_id?, "project-123")).to be true
        end
      end

      context "with nil" do
        it "returns false" do
          expect(tester.send(:semantic_id?, nil)).to be false
        end
      end

      context "with string inputs that are just integers" do
        it "returns false for string '123'" do
          expect(tester.send(:semantic_id?, "123")).to be false
        end

        it "returns false for string '0'" do
          expect(tester.send(:semantic_id?, "0")).to be false
        end
      end

      context "with integer inputs" do
        it "returns false for integer 123" do
          expect(tester.send(:semantic_id?, 123)).to be false
        end

        it "returns false for integer 0" do
          expect(tester.send(:semantic_id?, 0)).to be false
        end
      end

      context "with other data types" do
        it "returns false for array of integers" do
          expect(tester.send(:semantic_id?, [123])).to be false
        end

        it "returns false for hash" do
          expect(tester.send(:semantic_id?, { id: 123 })).to be false
        end
      end
    end
  end
end
