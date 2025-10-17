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

require_relative "../support/pages/meetings/show"

RSpec.describe "Meeting drag and drop", :js, :selenium do
  shared_let(:project) { create(:project, enabled_module_names: %w[meetings]) }
  shared_let(:user) do
    create(:user,
           member_with_permissions: { project => %i[view_meetings manage_agendas] })
  end
  shared_let(:meeting) do
    create(:meeting,
           project:,
           author: user,
           state: :in_progress)
  end
  let!(:section1) { create(:meeting_section, meeting:, title: "Section 1") }
  let!(:section2) { create(:meeting_section, meeting:, title: "Section 2") }
  let!(:agenda_item) { create(:meeting_agenda_item, meeting:, meeting_section: section1, title: "Item to drag") }

  let(:show_page) { Pages::Meetings::Show.new(meeting) }

  before do
    login_as user
  end

  it "allows dragging an agenda item from one section to another" do
    show_page.visit!
    show_page.expect_agenda_item_in_section(title: "Item to drag", section: section1)

    item_element = page.find("#meeting-agenda-items-item-component-show-component-#{agenda_item.id}")
    drag_handle = item_element.find(".handle svg")

    target_section = page.find("#meeting-sections-show-component-#{section2.id}")

    drag_n_drop_element(from: drag_handle, to: target_section)

    sleep 1

    show_page.expect_no_agenda_item_in_section(title: "Item to drag", section: section1)
    show_page.expect_agenda_item_in_section(title: "Item to drag", section: section2)

    wait_for_network_idle

    expect(agenda_item.reload.meeting_section).to eq(section2)
  end
end
