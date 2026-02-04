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

RSpec.describe "Backlogs Admin Settings", :js do
  let!(:type1) { create(:type, name: "Story", position: 1) }
  let!(:type2) { create(:type_feature,        position: 2) }
  let!(:type3) { create(:type_task,           position: 3) }
  let!(:type4) { create(:type_milestone,      position: 4) }

  let(:story_autocompleter) { FormFields::Primerized::AutocompleteField.new("story_types", selector: "[data-test-selector='story_type_autocomplete']") }
  let(:task_autocompleter) { FormFields::Primerized::AutocompleteField.new("story_types", selector: "[data-test-selector='task_type_autocomplete']") }

  let(:current_user) { create(:admin) }

  before do
    login_as current_user

    visit admin_backlogs_settings_path
  end

  scenario "updating story types" do
    expect(page).to have_heading "Backlogs"

    story_autocompleter.select_option "Feature", "Story"

    click_on "Save"

    expect_and_dismiss_flash type: :success, message: "Successful update."

    story_autocompleter.expect_selected "Feature", "Story"
  end


  scenario "updating task type" do
    expect(page).to have_heading "Backlogs"

    task_autocompleter.select_option "Task"

    click_on "Save"

    expect_and_dismiss_flash type: :success, message: "Successful update."

    task_autocompleter.expect_selected "Task"
  end

  scenario "ensuring the same type is not selected as story and task type" do
    expect(page).to have_heading "Backlogs"

    wait_for_network_idle

    wait_for_autocompleter_options_to_be_loaded
    story_autocompleter.expect_blank
    task_autocompleter.expect_blank

    # Select a value in the story autocompleter...
    story_autocompleter.select_option "Feature"
    story_autocompleter.expect_selected "Feature"
    story_autocompleter.expect_not_disabled "Story"
    story_autocompleter.close_autocompleter

    # ... which is then disabled in the task autocompleter.
    task_autocompleter.open_options
    task_autocompleter.expect_disabled "Feature"

    # Other way around: Select a value in the task automcompleter...
    task_autocompleter.select_option "Story"
    task_autocompleter.expect_selected "Story"
    task_autocompleter.close_autocompleter

    # ... which will be disabled in the story autocompleter
    story_autocompleter.open_options
    story_autocompleter.expect_disabled "Story"
    story_autocompleter.expect_selected "Feature"
  end

  scenario "updating points burn direction" do
    expect(page).to have_heading "Backlogs"

    choose "Down", fieldset: "Points burn up/down"

    click_on "Save"

    expect_and_dismiss_flash type: :success, message: "Successful update."

    expect(page).to have_checked_field "Down", fieldset: "Points burn up/down"
  end

  scenario "updating template for wiki page" do
    expect(page).to have_heading "Backlogs"

    fill_in "Template for sprint wiki page", with: "my_sprint_wiki_page"

    click_on "Save"

    expect_and_dismiss_flash type: :success, message: "Successful update."

    expect(page).to have_field "Template for sprint wiki page", with: "my_sprint_wiki_page"
  end
end
