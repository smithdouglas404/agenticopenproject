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

require "rails_helper"

RSpec.describe Agile::BacklogBucket do
  let(:project) { create(:project) }

  subject(:backlog_bucket) do
    described_class.new(name: "Bla Bla", project:)
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:project) }
  end

  describe "associations" do
    it { is_expected.to have_many(:work_packages).inverse_of(:backlog_bucket).dependent(:nullify) }
    it { is_expected.to belong_to(:project) }
  end

  describe "work_package association" do
    let(:backlog_bucket) { create(:backlog_bucket, project:) }
    let(:work_package) { create(:work_package, project:, backlog_bucket:) }

    it "can have work packages associated" do
      expect(backlog_bucket.work_packages).to include(work_package)
    end

    it "nullifies work_package backlog_bucket_id when destroyed" do
      work_package_id = work_package.id
      backlog_bucket.destroy!
      expect(WorkPackage.find(work_package_id).backlog_bucket_id).to be_nil
    end

    it "orders work packages by position" do
      work_package_nil = create(:work_package, project:, backlog_bucket:).tap { it.update_columns(position: nil) }
      work_package2 = create(:work_package, project:, backlog_bucket:, position: 2)
      work_package1 = create(:work_package, project:, backlog_bucket:, position: 1)

      expect(backlog_bucket.work_packages.reload.to_a).to eq([work_package1, work_package2, work_package_nil])
    end
  end

  describe ".order_alphabetically" do
    it "returns buckets sorted by name" do
      bucket3 = create(:backlog_bucket, project:, name: "foo")
      bucket1 = create(:backlog_bucket, project:, name: "bar")
      bucket2 = create(:backlog_bucket, project:, name: "baz")

      expect(described_class.order_alphabetically).to eq([bucket1, bucket2, bucket3])
    end
  end
end
