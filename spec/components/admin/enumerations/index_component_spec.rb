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

RSpec.describe Admin::Enumerations::IndexComponent, type: :component do
  current_user { create(:admin) }

  let!(:priority_one) { create(:issue_priority, name: "Critical", position: 1) }
  let!(:priority_two) { create(:issue_priority, name: "Normal", position: 2) }

  it "renders draggable rows as generic drag-and-drop items" do
    with_request_url("/admin/settings/work_package_priorities") do
      render_inline(described_class.new(enumerations: IssuePriority.order(:position)))
    end

    row = page.find("[data-test-selector='enumeration-row-#{priority_one.id}']")

    expect(row["data-generic-drag-and-drop-target"]).to eq("item")
    expect(row["data-draggable-id"]).to eq(priority_one.id.to_s)
    expect(row["data-draggable-type"]).to eq("enumeration")
    expect(row["data-drop-url"]).to end_with("/admin/settings/work_package_priorities/#{priority_one.id}/move")
  end
end
