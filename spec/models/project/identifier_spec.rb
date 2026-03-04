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

RSpec.describe Project::Identifier do
  let(:project) { create(:project) }
  let(:another_project) { create(:project) }

  describe "associations" do
    it { is_expected.to belong_to(:project).required }
  end

  describe "validations" do
    context "with handle uniqueness" do
      it "does not allow two projects to have the same handle" do
        create(:project_identifier, project:, handle: "unique-handle", current: true)
        duplicate_handle = build(:project_identifier, project: another_project, handle: "unique-handle", current: true)

        expect(duplicate_handle).not_to be_valid
        expect(duplicate_handle.errors[:handle]).to include("has already been taken.")
      end

      it "does not allow the same handle for the same project more than once" do
        create(:project_identifier, project:, handle: "same-handle", current: true)
        new_handle = build(:project_identifier, project:, handle: "same-handle", current: false)

        expect(new_handle).not_to be_valid
        expect(new_handle.errors[:handle]).to include("has already been taken.")
      end
    end

    context "with current handle uniqueness per project" do
      it "does not allow multiple current handles for the same project" do
        create(:project_identifier, project:, handle: "handle-one", current: true)
        second_current = build(:project_identifier, project:, handle: "handle-two", current: true)

        expect(second_current).not_to be_valid
        expect(second_current.errors[:project_id]).to include("has already been taken.")
      end

      it "allows one current and multiple non-current handles for the same project" do
        create(:project_identifier, project:, handle: "current-handle", current: true)
        handle_one = create(:project_identifier, project:, handle: "old-handle-one", current: false)
        handle_two = create(:project_identifier, project:, handle: "old-handle-two", current: false)

        expect(project.identifiers.count).to eq(3)
        expect(project.identifiers.current.count).to eq(1)
        expect(handle_one).to be_valid
        expect(handle_two).to be_valid
      end

      it "allows multiple current handles (but only for different projects)" do
        project_current = create(:project_identifier, project:, handle: "handle", current: true)
        another_project_current = create(:project_identifier, project: another_project, handle: "another-handle", current: true)

        expect(project_current).to be_valid
        expect(another_project_current).to be_valid
      end
    end

    context "with format restrictions" do
      it "allows lowercase letters, numbers and dashes" do
        project_identifier = create(:project_identifier, project:, handle: "handle-123")

        expect(project_identifier).to be_valid
      end

      it "disallows uppercase letters" do
        project_identifier = build(:project_identifier, project:, handle: "Handle-123")

        expect(project_identifier).not_to be_valid
        expect(project_identifier.errors[:handle]).to include("is invalid.")
      end

      it "disallows special characters" do
        project_identifier = build(:project_identifier, project:, handle: "test-handle-123!")

        expect(project_identifier).not_to be_valid
        expect(project_identifier.errors[:handle]).to include("is invalid.")
      end

      it "disallows to long handles" do
        long_handle = "a" * 101
        project_identifier = build(:project_identifier, project:, handle: long_handle)

        expect(project_identifier).not_to be_valid
        expect(project_identifier.errors[:handle]).to include("is too long (maximum is 100 characters).")
      end

      it "disallows reserved handles" do
        handles = %w[new menu queries filters]
        handles.each do |handle|
          project_identifier = build(:project_identifier, project:, handle: handle)

          expect(project_identifier).not_to be_valid
          expect(project_identifier.errors[:handle]).to include("is reserved.")
        end
      end
    end
  end

  describe "database constraints" do
    it "enforces handle uniqueness at database level" do
      create(:project_identifier, project:, handle: "db-unique-handle", current: true)

      expect do
        handle = build(:project_identifier, project: another_project, handle: "db-unique-handle", current: true)
        handle.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces current uniqueness per project at database level" do
      create(:project_identifier, project:, handle: "current-1", current: true)

      expect do
        handle = build(:project_identifier, project:, handle: "current-2", current: true)
        handle.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "dependent destroy" do
    it "deletes all handles when the project is deleted" do
      project_with_handles = create(:project)
      create(:project_identifier, project: project_with_handles, handle: "handle-one", current: true)
      create(:project_identifier, project: project_with_handles, handle: "handle-two", current: false)

      expect { project_with_handles.destroy }.to change(described_class, :count).by(-2)
      expect(described_class.where(project_id: project_with_handles.id)).to be_empty
    end
  end
end
