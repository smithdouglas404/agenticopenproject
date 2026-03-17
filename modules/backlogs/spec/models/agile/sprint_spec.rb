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

RSpec.describe Agile::Sprint do
  let(:project) { create(:project) }

  subject(:sprint) do
    described_class.new(name: "Sprint 1",
                        project:,
                        start_date: Time.zone.today,
                        finish_date: Time.zone.today + 14.days)
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:finish_date) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_inclusion_of(:status).in_array(described_class.statuses.keys) }

    it "validates finish_date is after or equal to start_date" do
      sprint.finish_date = sprint.start_date - 1.day
      expect(sprint).not_to be_valid
      expect(sprint.errors[:finish_date]).to include(/must be greater than or equal to/)
    end

    it "does not validate finish_date comparison when start_date is nil" do
      sprint.start_date = nil
      sprint.finish_date = Time.zone.today
      expect(sprint).not_to be_valid
      expect(sprint.errors[:start_date]).to be_present
      expect(sprint.errors[:finish_date]).not_to include(/must be greater than or equal to/)
    end

    it "still validates finish_date presence even when start_date is nil" do
      sprint.start_date = nil
      sprint.finish_date = nil
      expect(sprint).not_to be_valid
      expect(sprint.errors[:finish_date]).to be_present
    end

    context "with active sprint validation" do
      it "allows one active sprint per project" do
        sprint.status = "active"
        expect(sprint).to be_valid
      end

      it "prevents multiple active sprints in the same project" do
        create(:agile_sprint, project:, status: "active")
        sprint.status = "active"
        expect(sprint).not_to be_valid
        expect(sprint.errors[:status]).to include("only one active sprint is allowed per project.")
      end

      it "allows multiple active sprints in different projects" do
        other_project = create(:project)
        create(:agile_sprint, project: other_project, status: "active")
        sprint.status = "active"
        expect(sprint).to be_valid
      end

      it "allows updating an existing active sprint" do
        sprint.status = "active"
        sprint.save!
        sprint.name = "Updated Sprint"
        expect(sprint).to be_valid
      end

      it "allows multiple non-active sprints in the same project" do
        create(:agile_sprint, project:, status: "completed")
        create(:agile_sprint, project:, status: "in_planning")
        sprint.status = "in_planning"
        expect(sprint).to be_valid
      end
    end
  end

  describe "enums" do
    it "has status enum with correct values" do
      expect(described_class.statuses.keys).to contain_exactly("in_planning", "active", "completed")
    end

    it "status defaults to in_planning" do
      expect(sprint).to be_in_planning
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:work_packages).dependent(:nullify) }
    it { is_expected.to belong_to(:project) }
  end

  describe "work_package association" do
    let(:sprint) { create(:agile_sprint, project:) }
    let(:work_package) { create(:work_package, project:, sprint:) }

    it "can have work packages associated" do
      expect(sprint.work_packages).to include(work_package)
    end

    it "nullifies work_package sprint_id when destroyed" do
      work_package_id = work_package.id
      sprint.destroy!
      expect(WorkPackage.find(work_package_id).sprint_id).to be_nil
    end
  end
end
