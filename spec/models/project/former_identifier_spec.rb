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

RSpec.describe Project::FormerIdentifier do
  let(:project) { create(:project) }
  let(:another_project) { create(:project) }

  describe "associations" do
    it { is_expected.to belong_to(:project).required }
  end

  describe "validations" do
    context "with identifier uniqueness" do
      it "does not allow the same identifier more than once" do
        create(:project_former_identifier, project:, identifier: "unique-identifier")
        duplicate_identifier = build(:project_former_identifier, project: another_project, identifier: "unique-identifier")

        expect(duplicate_identifier).not_to be_valid
        expect(duplicate_identifier.errors[:identifier]).to include("has already been taken.")
      end
    end

    context "with identifier presence" do
      it "does not allow an empty identifier" do
        identifier = build(:project_former_identifier, project: another_project, identifier: "")

        expect(identifier).not_to be_valid
        expect(identifier.errors[:identifier]).to include("can't be blank.")
      end
    end
  end

  describe "database constraints" do
    it "enforces identifier uniqueness at database level" do
      create(:project_former_identifier, project:, identifier: "db-unique-identifier")
      identifier = build(:project_former_identifier, project: another_project, identifier: "db-unique-identifier")

      expect do
        identifier.save!(validate: false)
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "enforces identifier presence at database level" do
      identifier = build(:project_former_identifier, project:, identifier: nil)

      expect do
        identifier.save!(validate: false)
      end.to raise_error(ActiveRecord::NotNullViolation)
    end
  end

  describe "dependent destroy" do
    it "deletes all identifiers when the project is deleted" do
      project_with_identifiers = create(:project)
      create(:project_former_identifier, project: project_with_identifiers, identifier: "identifier-one")
      create(:project_former_identifier, project: project_with_identifiers, identifier: "identifier-two")

      expect { project_with_identifiers.destroy }.to change(described_class, :count).by(-2)
      expect(described_class.where(project_id: project_with_identifiers.id)).to be_empty
    end
  end
end
