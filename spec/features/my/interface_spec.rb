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

RSpec.describe "My account Interface settings",
               :js, :selenium do
  let(:user) { create(:user) }

  before do
    login_as(user)
    visit my_account_path
  end

  it "allows the user to specify their preferred color mode" do
    click_on "Interface"

    select "Light", from: "Color mode"
    click_on "Update look and feel"

    expect(page).to have_css("body[data-color-mode='light'][data-light-theme='light']")

    select "Light high contrast", from: "Color mode"
    click_on "Update look and feel"

    expect(page).to have_css("body[data-color-mode='light'][data-light-theme='light_high_contrast']")

    select "Dark", from: "Color mode"
    click_on "Update look and feel"

    expect(page).to have_css("body[data-color-mode='dark'][data-dark-theme='dark']")

    select "Dark high contrast", from: "Color mode"
    click_on "Update look and feel"

    expect(page).to have_css("body[data-color-mode='dark'][data-dark-theme='dark_high_contrast']")

    select "Automatic (match OS color mode)", from: "Color mode"
    click_on "Update look and feel"

    expect(page).to have_css("body[data-auto-theme-switcher-mode-value='sync_with_os']")
  end

  describe "Automatic (match OS color  mode)" do
    def set_automatic_mode_with_reload
      click_on "Interface"

      select "Automatic (match OS color mode)", from: "Color mode"
      click_on "Update look and feel"
    end

    context "with OS in dark mode", driver: :chrome_dark_mode do
      it "syncs with OS colour mode" do
        set_automatic_mode_with_reload
        expect(page).to have_css("body[data-color-mode='dark'][data-dark-theme='dark']")
      end
    end
  end
end
