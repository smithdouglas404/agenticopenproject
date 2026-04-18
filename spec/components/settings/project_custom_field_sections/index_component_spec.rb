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

RSpec.describe Settings::ProjectCustomFieldSections::IndexComponent, type: :component do
  current_user { create(:admin) }

  let!(:first_section) { create(:project_custom_field_section, name: "Basics") }
  let!(:second_section) { create(:project_custom_field_section, name: "Advanced") }

  it "renders section rows as generic drag-and-drop items" do
    render_inline(described_class.new(project_custom_field_sections: ProjectCustomFieldSection.order(:position)))

    row = page.find("[data-draggable-id='#{first_section.id}']")

    expect(row["data-generic-drag-and-drop-target"]).to eq("item")
    expect(row["data-draggable-id"]).to eq(first_section.id.to_s)
    expect(row["data-draggable-type"]).to eq("section")
    expect(row["data-drop-url"]).to end_with("/admin/settings/project_custom_field_sections/#{first_section.id}/drop")
  end
end
