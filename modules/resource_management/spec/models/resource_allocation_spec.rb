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

RSpec.describe ResourceAllocation do
  describe "associations" do
    it { is_expected.to belong_to(:entity).required }
    it { is_expected.to belong_to(:principal).class_name("User").inverse_of(:resource_allocations).optional }
    it { is_expected.to belong_to(:requested_by).class_name("User").optional }
    it { is_expected.to belong_to(:reviewed_by).class_name("User").optional }
  end

  describe "state enum" do
    it "exposes the four allowed string-backed states" do
      expect(described_class.states).to eq(
        "requested" => "requested",
        "allocated" => "allocated",
        "rejected" => "rejected",
        "canceled" => "canceled"
      )
    end

    it "rejects unknown state values" do
      expect { described_class.new(state: "unknown") }.to raise_error(ArgumentError)
    end

    it "exposes a factory trait per state value" do
      described_class.states.each_key do |value|
        expect(build(:resource_allocation, value.to_sym).state).to eq(value)
      end
    end
  end

  describe "#allocated_hours" do
    subject(:allocation) { described_class.new }

    describe "reader" do
      it "returns the persisted minutes as hours" do
        allocation.allocated_time = 150
        expect(allocation.allocated_hours).to eq(2.5)
      end

      it "is nil when allocated_time is unset" do
        expect(allocation.allocated_hours).to be_nil
      end
    end

    describe "writer" do
      it "stores a numeric value of hours as minutes" do
        allocation.allocated_hours = 8
        expect(allocation.allocated_time).to eq(480)
      end

      it "parses a duration string via chronic duration" do
        allocation.allocated_hours = "2h30m"
        expect(allocation.allocated_time).to eq(150)
      end

      it "parses a decimal-hours string" do
        allocation.allocated_hours = "2.5"
        expect(allocation.allocated_time).to eq(150)
      end

      it "clears the value when given nil" do
        allocation.allocated_time = 480
        allocation.allocated_hours = nil
        expect(allocation.allocated_time).to be_nil
      end

      it "falls back to nil for an unparseable string (so validation can reject it)" do
        allocation.allocated_hours = "not a duration"
        expect(allocation.allocated_time).to be_nil
      end
    end
  end

  describe "entity GlobalID handling" do
    shared_let(:project) { create(:project) }
    shared_let(:work_package) { create(:work_package, project:) }

    subject(:allocation) { described_class.new }

    describe "#entity_gid" do
      it "returns the GlobalID string of the entity" do
        allocation.entity = work_package
        expect(allocation.entity_gid).to eq(work_package.to_gid.to_s)
      end

      it "is an empty string when no entity is set" do
        expect(allocation.entity_gid).to eq("")
      end
    end

    describe "#entity=" do
      it "assigns a plain record directly" do
        allocation.entity = work_package
        expect(allocation.entity).to eq(work_package)
      end

      it "resolves a GlobalID string to the record" do
        allocation.entity = work_package.to_gid.to_s
        expect(allocation.entity).to eq(work_package)
      end

      it "round-trips an entity through entity_gid" do
        allocation.entity = work_package.to_gid.to_s
        expect(allocation.entity_gid).to eq(work_package.to_gid.to_s)
      end

      it "ignores a GlobalID of a type outside ALLOWED_ENTITY_TYPES" do
        disallowed = create(:user)
        allocation.entity = disallowed.to_gid.to_s
        expect(allocation.entity).to be_nil
      end
    end
  end

  describe "validations" do
    shared_let(:project) { create(:project, enabled_module_names: %w[resource_management]) }
    shared_let(:owner) { create(:user, member_with_permissions: { project => %i[view_resource_planners] }) }
    shared_let(:work_package) { create(:work_package, project:) }

    let(:allocation) { build(:resource_allocation, entity: work_package, principal: owner) }

    it "is valid with the factory defaults" do
      expect(allocation).to be_valid
    end

    describe "presence" do
      it "requires entity" do
        allocation.entity = nil
        expect(allocation).not_to be_valid
        expect(allocation.errors[:entity]).to be_present
      end

      it "requires state" do
        allocation.state = nil
        expect(allocation).not_to be_valid
        expect(allocation.errors[:state]).to be_present
      end

      it "requires start_date" do
        allocation.start_date = nil
        expect(allocation).not_to be_valid
        expect(allocation.errors[:start_date]).to be_present
      end

      it "requires end_date" do
        allocation.end_date = nil
        expect(allocation).not_to be_valid
        expect(allocation.errors[:end_date]).to be_present
      end

      it "requires allocated_time" do
        allocation.allocated_time = nil
        expect(allocation).not_to be_valid
        expect(allocation.errors[:allocated_time]).to be_present
      end

      it "does not require principal (column is nullable)" do
        allocation.principal = nil
        expect(allocation).to be_valid
      end
    end

    describe "entity type" do
      it "lists the supported entity types" do
        expect(described_class::ALLOWED_ENTITY_TYPES).to eq(%w[WorkPackage])
      end

      it "is valid when the entity type is in the allowed list" do
        allocation.entity = work_package
        expect(allocation).to be_valid
      end

      it "is invalid when the entity type is outside the allowed list" do
        allocation.entity = create(:resource_planner, project:, principal: owner)
        expect(allocation).not_to be_valid
        expect(allocation.errors.symbols_for(:entity_type)).to include(:inclusion)
      end
    end

    describe "allocated_time numericality" do
      it "is invalid when zero" do
        allocation.allocated_time = 0
        expect(allocation).not_to be_valid
        expect(allocation.errors.symbols_for(:allocated_time)).to include(:greater_than)
      end

      it "is invalid when negative" do
        allocation.allocated_time = -1
        expect(allocation).not_to be_valid
        expect(allocation.errors.symbols_for(:allocated_time)).to include(:greater_than)
      end

      it "is valid when positive" do
        allocation.allocated_time = 1
        expect(allocation).to be_valid
      end
    end

    describe "date range" do
      context "when end_date is after start_date" do
        before do
          allocation.start_date = Date.new(2026, 1, 1)
          allocation.end_date = Date.new(2026, 1, 2)
        end

        it "is valid" do
          expect(allocation).to be_valid
        end
      end

      context "when end_date equals start_date" do
        before do
          allocation.start_date = Date.new(2026, 1, 1)
          allocation.end_date = Date.new(2026, 1, 1)
        end

        it "is invalid" do
          expect(allocation).not_to be_valid
          expect(allocation.errors.symbols_for(:end_date)).to include(:greater_than_start_date)
        end
      end

      context "when end_date is before start_date" do
        before do
          allocation.start_date = Date.new(2026, 1, 5)
          allocation.end_date = Date.new(2026, 1, 2)
        end

        it "is invalid" do
          expect(allocation).not_to be_valid
          expect(allocation.errors.symbols_for(:end_date)).to include(:greater_than_start_date)
        end
      end
    end
  end

  describe "user_filter serialization" do
    shared_let(:project) { create(:project, enabled_module_names: %w[resource_management]) }
    shared_let(:owner) { create(:user, member_with_permissions: { project => %i[view_resource_planners] }) }
    shared_let(:work_package) { create(:work_package, project:) }

    it "serializes filters using the same coder as UserQuery" do
      coder = described_class.type_for_attribute(:user_filter).coder
      user_query_coder = UserQuery.type_for_attribute(:filters).coder

      expect(coder).to be_a(Queries::Serialization::Filters)
      expect(coder.klass).to eq(UserQuery)
      expect(coder.registered_filters).to eq(user_query_coder.registered_filters)
    end

    it "round-trips a UserQuery filter through the database" do
      filter = UserQuery.new.filter_for(:name)
      filter.operator = "~"
      filter.values = ["alice"]

      allocation = create(:resource_allocation, entity: work_package, principal: owner, user_filter: [filter])

      reloaded = described_class.find(allocation.id)
      expect(reloaded.user_filter.size).to eq(1)
      expect(reloaded.user_filter.first).to be_a(Queries::Users::Filters::NameFilter)
      expect(reloaded.user_filter.first.operator).to eq("~")
      expect(reloaded.user_filter.first.values).to eq(["alice"])
    end

    it "defaults to an empty array" do
      allocation = create(:resource_allocation, entity: work_package, principal: owner)
      expect(allocation.reload.user_filter).to eq([])
    end
  end
end
