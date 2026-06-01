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
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require "rails_helper"

RSpec.describe Admin::Enumerations::IndexComponent, type: :component do
  subject(:rendered_component) do
    with_controller_class(Admin::Settings::WorkPackagePrioritiesController) do
      with_request_url("/admin/settings/work_package_priorities") do
        render_inline(described_class.new(enumerations:))
      end
    end
  end

  let(:enumerations) { IssuePriority.order(:position) }

  context "with enumerations" do
    let!(:normal_priority) { create(:issue_priority, name: "Normal", position: 1) }
    let!(:high_priority) { create(:issue_priority, name: "High", position: 2) }

    it "renders the enumerations in a border box list with preserved controls and drag-and-drop data" do
      expect(rendered_component).to have_css(".Box.op-border-box-list")
      expect(rendered_component).to have_css(".Box[data-generic-drag-and-drop-target='container']")
      expect(rendered_component).to have_css(".Box[data-target-container-accessor=':scope > ul']")
      expect(rendered_component).to have_css(".Box[data-target-allowed-drag-type='enumeration']")

      expect(rendered_component).to have_css("[data-test-selector='add-enumeration-button']")
      expect(rendered_component).to have_text(IssuePriority.model_name.human(count: :other))

      rows = rendered_component.css(".Box-row[data-draggable-type='enumeration']")
      expect(rows.size).to eq(2)

      expect(rendered_component).to have_css(
        ".Box-row[data-test-selector='enumeration-row-#{normal_priority.id}']" \
        "[data-draggable-id='#{normal_priority.id}']" \
        "[data-draggable-type='enumeration']" \
        "[data-drop-url$='/admin/settings/work_package_priorities/#{normal_priority.id}/move']",
        text: "Normal"
      )
      expect(rendered_component).to have_css(
        ".Box-row[data-test-selector='enumeration-row-#{high_priority.id}']" \
        "[data-draggable-id='#{high_priority.id}']" \
        "[data-draggable-type='enumeration']" \
        "[data-drop-url$='/admin/settings/work_package_priorities/#{high_priority.id}/move']",
        text: "High"
      )
    end
  end

  context "without enumerations" do
    it "renders the existing empty result text as a border box list row" do
      expect(rendered_component).to have_css(".Box.op-border-box-list")
      expect(rendered_component).to have_css(".Box-row", text: I18n.t(:no_results_title_text))
    end
  end
end
