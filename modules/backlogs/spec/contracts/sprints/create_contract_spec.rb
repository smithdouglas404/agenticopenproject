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

RSpec.describe Sprints::CreateContract do
  let(:project) { build_stubbed(:project) }
  let(:user) { build_stubbed(:user) }
  let(:sprint) do
    Agile::Sprint.new(name: sprint_name,
                      project:,
                      start_date: sprint_start_date,
                      finish_date: sprint_finish_date,
                      status: sprint_status,
                      sharing: sprint_sharing)
  end
  let(:sprint_name) { "Sprint 1" }
  let(:sprint_start_date) { Time.zone.today }
  let(:sprint_finish_date) { Time.zone.today + 14.days }
  let(:sprint_status) { "in_planning" }
  let(:sprint_sharing) { "none" }
  let(:permissions) { [:create_sprints] }

  subject(:contract) { described_class.new(sprint, user) }

  before do
    mock_permissions_for(user) do |mock|
      mock.allow_in_project(*permissions, project:) if project
    end
  end

  def expect_valid(valid, symbols = {})
    expect(contract.validate).to eq(valid)

    symbols.each do |key, arr|
      expect(contract.errors.symbols_for(key)).to match_array arr
    end
  end

  shared_examples "is valid" do
    it "is valid" do
      expect_valid(true)
    end
  end

  describe "validation" do
    context "with valid attributes and permissions" do
      it_behaves_like "is valid"
    end

    context "when project is nil" do
      let(:project) { nil }

      it "is invalid (model validation)" do
        expect_valid(false, project: %i[blank])
      end
    end

    context "when user does not have create_sprints permission" do
      let(:permissions) { [:view_work_packages] }

      it "is invalid" do
        expect_valid(false, base: %i[error_unauthorized])
      end
    end

    context "when user has no permissions in project" do
      let(:permissions) { [] }

      it "is invalid" do
        expect_valid(false, base: %i[error_unauthorized])
      end
    end

    context "when name is blank" do
      let(:sprint_name) { "" }

      it "is invalid (model validation)" do
        expect_valid(false, name: %i[blank])
      end
    end

    context "when start_date is blank" do
      let(:sprint_start_date) { nil }

      it "is invalid (model validation)" do
        expect_valid(false, start_date: %i[blank])
      end
    end

    context "when finish_date is blank" do
      let(:sprint_finish_date) { nil }

      it "is invalid (model validation)" do
        expect_valid(false, finish_date: %i[blank blank])
      end
    end

    context "when finish_date is before start_date" do
      let(:sprint_start_date) { Time.zone.today }
      let(:sprint_finish_date) { Time.zone.today - 1.day }

      it "is invalid (model validation)" do
        expect_valid(false, finish_date: %i[greater_than_or_equal_to])
      end
    end

    context "when user is admin without project permission" do
      let(:user) { build_stubbed(:admin) }
      let(:permissions) { [] }

      it_behaves_like "is valid"
    end
  end
end
