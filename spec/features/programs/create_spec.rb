# frozen_string_literal: true

# -- copyright
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
# ++

require "spec_helper"

RSpec.describe "Programs",
               "creation",
               :js do
  shared_let(:user_with_permissions) do
    create(:user,
           global_permissions: :add_programs)
  end
  # Role granted to creator on program creation to be able to access the program.
  shared_let(:default_project_role) { create(:project_role) }

  let(:projects_page) { Pages::Projects::Index.new }

  current_user { user_with_permissions }

  it "can create a program", with_flag: { portfolio_models: true } do
    projects_page.visit!

    projects_page.create_new_workspace

    expect(page).to have_heading "New program"
    # This should be an
    #   expect(page).to have_no_field "Subproject of"
    # But this leads to a false negative. Even with the field being there, is the
    # expectation passed.
    expect(page).to have_no_content "Subproject of"

    fill_in "Name", with: "Foo bar"
    click_on "Create"

    expect_and_dismiss_flash type: :success, message: "Successful creation."

    expect(page).to have_current_path /\/projects\/foo-bar\/?/
    expect(page).to have_content "Foo bar"
  end

  context "without the necessary permissions to create programs", with_flag: { portfolio_models: true } do
    current_user { create(:user) }

    it "cannot create the program" do
      visit new_program_path

      expect(page).to have_content "[Error 403] You are not authorized to access this page."
    end
  end

  context "without the feature flag being active", with_flag: { portfolio_models: false } do
    it "cannot create the program" do
      visit new_program_path

      expect(page).to have_content "[Error 403] You are not authorized to access this page."
    end
  end
end
