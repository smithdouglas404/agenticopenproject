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
require_relative "support/theme_matchers"

RSpec.describe "My account Interface settings",
               :js, :selenium do
  include ThemeTestHelpers

  let(:user) { create(:user) }

  before do
    login_as(user)
    visit my_account_path
  end

  it "allows the user to specify their preferred color mode" do
    navigate_to_interface_settings

    select_theme "Light"
    expect(page).to have_theme("light")

    select_theme "Dark"
    expect(page).to have_theme("dark")

    select_theme "Automatic (match OS color mode)"
    expect(page).to have_auto_theme_config({})
  end

  it "allows user to increase contrast for single theme modes" do
    navigate_to_interface_settings

    select "Light", from: "Color mode"

    expect(page).to have_field("Increase contrast")
    expect(page).to have_no_field("Force high-contrast when in Light mode")
    expect(page).to have_no_field("Force high-contrast when in Dark mode")

    enable_contrast_for_single_theme
    expect(page).to have_theme("light", high_contrast: true)

    select "Dark", from: "Color mode"
    enable_contrast_for_single_theme
    expect(page).to have_theme("dark", high_contrast: true)
  end

  it "shows appropriate contrast options based on theme selection" do
    navigate_to_interface_settings

    select "Light", from: "Color mode"
    expect(page).to have_field("Increase contrast")
    expect(page).to have_no_field("Force high-contrast when in Light mode")
    expect(page).to have_no_field("Force high-contrast when in Dark mode")

    select "Automatic (match OS color mode)", from: "Color mode"
    expect(page).to have_no_field("Increase contrast")
    expect(page).to have_field("Force high-contrast when in Light mode")
    expect(page).to have_field("Force high-contrast when in Dark mode")

    select "Dark", from: "Color mode"
    expect(page).to have_field("Increase contrast")
    expect(page).to have_no_field("Force high-contrast when in Light mode")
    expect(page).to have_no_field("Force high-contrast when in Dark mode")
  end

  describe "Automatic (match OS color mode)" do
    def set_automatic_mode_with_reload
      navigate_to_interface_settings
      select_theme "Automatic (match OS color mode)"
    end

    it "allows user to configure auto-contrast for both light and dark modes" do
      navigate_to_interface_settings

      select "Automatic (match OS color mode)", from: "Color mode"
      configure_auto_contrast(light: true, dark: true)

      expect(page).to have_auto_theme_config(
        enable_auto_light_contrast: true,
        enable_auto_dark_contrast: true
      )
    end

    context "with OS in dark mode", driver: :chrome_dark_mode do
      it "syncs with OS colour mode" do
        set_automatic_mode_with_reload
        expect(page).to have_theme("dark")
      end
    end
  end
end
