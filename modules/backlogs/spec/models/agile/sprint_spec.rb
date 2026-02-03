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
  subject(:sprint) do
    described_class.new(name: "Sprint 1",
                        start_date: Time.zone.today,
                        end_date: Time.zone.today + 14.days)
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }

    it "validates end_date is after start_date" do
      sprint.end_date = sprint.start_date - 1.day
      expect(sprint).not_to be_valid
      expect(sprint.errors[:end_date]).to include("must be after the start date")
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:work_packages).dependent(:nullify) }
  end

  describe "enums" do
    it "has status enum with correct values" do
      expect(described_class.statuses.keys).to contain_exactly("in planning", "active", "completed")
    end
  end

  describe "default status" do
    it "defaults to in_planning" do
      expect(sprint.status).to eq("in planning")
    end
  end

  describe "work_package association" do
    let(:project) { create(:project) }
    let(:sprint) { create(:agile_sprint) }
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
