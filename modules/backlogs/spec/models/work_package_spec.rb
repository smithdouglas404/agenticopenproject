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

RSpec.describe WorkPackage do
  describe "can't be both in backlog bucket and sprint" do
    shared_let(:project) { create(:project) }
    shared_let(:backlog_bucket) { create(:backlog_bucket, project:) }
    shared_let(:sprint) { create(:agile_sprint, project:) }

    context "when already in a backlog bucket" do
      let(:work_package) { create(:work_package, project:, backlog_bucket:) }

      it "fails validation when being added to sprint" do
        work_package.assign_attributes(sprint:)

        expect(work_package).not_to be_valid
        expect(work_package.errors[:base]).to include(/cannot be assigned to both a sprint and a backlog bucket/)
      end

      it "fails being added to sprint" do
        work_package.assign_attributes(sprint:)

        expect do
          work_package.save!(validate: false)
        end.to raise_error(ActiveRecord::CheckViolation)
      end

      it "allows changing backlog bucket" do
        work_package.update(backlog_bucket: create(:backlog_bucket, project:))
      end

      it "allows replacing backlog bucket with sprint" do
        work_package.update(backlog_bucket: nil, sprint:)
      end
    end

    context "when already in a sprint" do
      let(:work_package) { create(:work_package, project:, sprint:) }

      it "fails validation when being added to backlog bucket" do
        work_package.assign_attributes(backlog_bucket:)

        expect(work_package).not_to be_valid
        expect(work_package.errors[:base]).to include(/cannot be assigned to both a sprint and a backlog bucket/)
      end

      it "fails being added to backlog bucket" do
        work_package.assign_attributes(backlog_bucket:)

        expect do
          work_package.save!(validate: false)
        end.to raise_error(ActiveRecord::CheckViolation)
      end

      it "allows changing sprint" do
        work_package.update(sprint: create(:agile_sprint, project:))
      end

      it "allows replacing sprint with backlog bucket" do
        work_package.update(backlog_bucket:, sprint: nil)
      end
    end
  end

  describe "backlog bucket must belong to the same project" do
    shared_let(:project) { create(:project) }
    let(:other_project) { create(:project) }
    let(:work_package) { build(:work_package, project:, backlog_bucket:) }

    context "when backlog bucket belongs to the same project" do
      let(:backlog_bucket) { create(:backlog_bucket, project:) }

      it "is valid" do
        expect(work_package).to be_valid
      end
    end

    context "when backlog bucket belongs to a different project" do
      let(:backlog_bucket) { create(:backlog_bucket, project: other_project) }

      it "is invalid" do
        expect(work_package).not_to be_valid
        expect(work_package.errors[:backlog_bucket]).to include(/must belong to the same project/)
      end
    end

    context "when backlog bucket is nil" do
      let(:backlog_bucket) { nil }

      it "is valid" do
        expect(work_package).to be_valid
      end
    end
  end

  describe ".order_by_position" do
    let(:work_packages) { create_list(:work_package, 3) }

    it "sorts by position ascending and places NULL positions last" do
      work_packages.each_with_index do |wp, idx|
        position = idx == 0 ? nil : idx
        wp.update_columns(position:)
      end

      ordered_positions = described_class
                      .where(id: work_packages.map(&:id))
                      .order_by_position
                      .pluck(:position)
      expect(ordered_positions).to eq([1, 2, nil])
    end
  end
end
