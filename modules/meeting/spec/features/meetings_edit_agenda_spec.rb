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

RSpec.describe "Meetings edit agenda", :js do
  include Components::Autocompleter::NgSelectAutocompleteHelpers

  shared_let(:project) { create(:project, enabled_module_names: %w[meetings work_package_tracking]) }
  shared_let(:user) do
    create :user,
           lastname: "First",
           preferences: { time_zone: "Etc/UTC" },
           member_with_permissions: { project => %i[view_meetings create_meetings edit_meetings delete_meetings manage_agendas
                                                    manage_outcomes view_work_packages] }
  end
  shared_let(:meeting) do
    create :meeting,
           project:,
           author: user,
           state: :in_progress
  end

  let(:current_user) { user }
  let(:show_page) { Pages::Meetings::Show.new(meeting) }

  before do
    login_as current_user
    show_page.visit!
  end

  it "allows simultaneous editing of multiple agenda items (OP#65082)" do
    show_page.add_agenda_item do
      fill_in "Title", with: "Agenda Item #1"
      fill_in_rich_text "Notes", with: "Preliminary notes ✅"
    end

    show_page.expect_agenda_item title: "Agenda Item #1"
    show_page.expect_notes "Preliminary notes ✅"

    first_item = MeetingAgendaItem.find_by(title: "Agenda Item #1")

    show_page.add_agenda_item do
      fill_in "Title", with: "Agenda Item #2"
      fill_in_rich_text "Notes", with: "More notes..."
    end

    show_page.expect_agenda_item title: "Agenda Item #2"
    show_page.expect_notes "More notes..."

    second_item = MeetingAgendaItem.find_by(title: "Agenda Item #2")

    show_page.edit_agenda_item(first_item, save: false) do
      expect(show_page).to have_selector :rich_text, "Notes", text: "Preliminary notes ✅"
    end

    show_page.edit_agenda_item(second_item, save: false) do
      expect(show_page).to have_selector :rich_text, "Notes", text: "More notes..."
    end
  end
end
