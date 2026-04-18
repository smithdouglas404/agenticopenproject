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

RSpec.describe MeetingSections::ShowComponent, type: :component do
  shared_let(:project) { create(:project, enabled_module_names: %w[meetings]) }
  shared_let(:user) do
    create(:user, member_with_permissions: { project => %i[view_meetings manage_agendas] })
  end

  current_user { user }

  let(:meeting) { create(:meeting, project:, author: user) }
  let(:meeting_section) { create(:meeting_section, meeting:) }
  let!(:agenda_item) { create(:meeting_agenda_item, meeting:, meeting_section:) }

  subject(:rendered_component) do
    render_inline(described_class.new(meeting_section:))
  end

  it "renders the section itself as a draggable item" do
    rendered_component

    section = page.find("[data-test-selector='meeting-section-container-#{meeting_section.id}']")
    expect(section["data-meetings--drag-and-drop-target"]).to eq("item")
    expect(section["data-draggable-id"]).to eq(meeting_section.id.to_s)
    expect(section["data-draggable-type"]).to eq("section")
  end

  it "puts the agenda-item drop target on the real list container" do
    rendered_component

    list = page.find(".Box > ul")
    expect(list["data-meetings--drag-and-drop-target"]).to eq("container")
    expect(list["data-target-id"]).to eq(meeting_section.id.to_s)
    expect(list["data-target-allowed-drag-type"]).to eq("agenda-item")
  end

  it "renders agenda rows as draggable items" do
    rendered_component

    row = page.find(".Box-row[data-draggable-id='#{agenda_item.id}']")
    expect(row["data-meetings--drag-and-drop-target"]).to eq("item")
    expect(row["data-draggable-type"]).to eq("agenda-item")
  end
end
