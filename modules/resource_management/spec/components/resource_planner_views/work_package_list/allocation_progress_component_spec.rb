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

RSpec.describe ResourcePlannerViews::WorkPackageList::AllocationProgressComponent, type: :component do
  # Loads the work package through the same select augmentation the view uses,
  # so `allocated_time_total` is present exactly as it is at render time.
  # `derived_hours` mimics a parent's rolled-up total work; `own_hours` mimics a
  # leaf whose work lives in `estimated_hours` (where derived stays nil).
  def loaded_work_package(allocated_minutes:, derived_hours: nil, own_hours: nil)
    work_package = create(:work_package)
    work_package.update_columns(derived_estimated_hours: derived_hours, estimated_hours: own_hours)
    if allocated_minutes.positive?
      create(:resource_allocation, entity: work_package, allocated_time: allocated_minutes)
    end

    ResourceAllocation
      .with_allocated_time(WorkPackage.where(id: work_package.id))
      .first
  end

  subject(:rendered) do
    render_inline(described_class.new(work_package:))
    page
  end

  context "when allocations cover only part of the scheduled work" do
    let(:work_package) { loaded_work_package(derived_hours: 35, allocated_minutes: 12 * 60) }

    it "renders allocated / scheduled, the coverage percentage and a partial accent bar" do
      expect(rendered).to have_text("12h / 35h")
      expect(rendered).to have_text("34%")
      expect(rendered).to have_css(".Progress-item.color-bg-accent-emphasis[style*='width: 34%']")
    end
  end

  context "when the work package is a leaf with only its own estimated work" do
    let(:work_package) { loaded_work_package(own_hours: 35, allocated_minutes: 12 * 60) }

    it "falls back to estimated_hours for the total work" do
      expect(rendered).to have_text("12h / 35h")
      expect(rendered).to have_text("34%")
    end
  end

  context "when allocations exactly cover the scheduled work" do
    let(:work_package) { loaded_work_package(derived_hours: 80, allocated_minutes: 80 * 60) }

    it "renders a full success bar at 100%" do
      expect(rendered).to have_text("100%")
      expect(rendered).to have_css(".Progress-item.color-bg-success-emphasis[style*='width: 100%']")
    end
  end

  context "when allocations exceed the scheduled work" do
    let(:work_package) { loaded_work_package(derived_hours: 20, allocated_minutes: 40 * 60) }

    it "renders a danger bar capped at 100% while the label shows the real ratio" do
      expect(rendered).to have_text("40h / 20h")
      expect(rendered).to have_text("200%")
      expect(rendered).to have_css(".Progress-item.color-bg-danger-emphasis[style*='width: 100%']")
    end
  end

  context "when nothing is allocated yet" do
    let(:work_package) { loaded_work_package(derived_hours: 100, allocated_minutes: 0) }

    it "renders an empty accent bar at 0%" do
      expect(rendered).to have_text("0h / 100h")
      expect(rendered).to have_text("0%")
      expect(rendered).to have_css(".Progress-item[style*='width: 0%']")
    end
  end

  context "when the work package has no scheduled work" do
    let(:work_package) { loaded_work_package(allocated_minutes: 12 * 60) }

    it "renders a danger alert icon instead of a bar" do
      expect(rendered).to have_no_css(".Progress-item")
      expect(rendered).to have_css(".octicon-alert-fill")
      expect(rendered).to have_text(I18n.t("resource_management.work_package_list.allocation.no_work"))
    end
  end
end
