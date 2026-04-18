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
# See COPYRIGHT and LICENSE files for more details.
#++

require "rails_helper"

RSpec.describe MeetingSections::ShowComponent, type: :component do
  current_user { create(:admin) }

  let(:project) { create(:project, enabled_module_names: %w[meetings]) }
  let(:meeting) { create(:meeting, project:) }
  let(:meeting_section) { create(:meeting_section, meeting:, title: "Discussion") }
  let!(:agenda_item) { create(:meeting_agenda_item, meeting:, meeting_section:, title: "Budget review") }

  it "renders meeting sections and agenda items as meetings drag-and-drop items" do
    render_inline(described_class.new(meeting_section:))

    section = page.find("[data-test-selector='meeting-section-container-#{meeting_section.id}']")
    agenda_row = page.find(".op-meeting-agenda-item-wrapper")

    expect(section["data-meetings--drag-and-drop-target"]).to eq("item")
    expect(section["data-draggable-id"]).to eq(meeting_section.id.to_s)
    expect(section["data-draggable-type"]).to eq("section")
    expect(section["data-drop-url"]).to end_with(
      "/projects/#{project.identifier}/meetings/#{meeting.id}/sections/#{meeting_section.id}/drop"
    )

    expect(agenda_row["data-meetings--drag-and-drop-target"]).to eq("item")
    expect(agenda_row["data-draggable-id"]).to eq(agenda_item.id.to_s)
    expect(agenda_row["data-draggable-type"]).to eq("agenda-item")
    expect(agenda_row["data-drop-url"]).to end_with(
      "/projects/#{project.identifier}/meetings/#{meeting.id}/agenda_items/#{agenda_item.id}/drop"
    )
  end
end
