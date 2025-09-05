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

RSpec::Matchers.define :have_theme do |theme, options = {}|
  match do |page|
    contrast_suffix = options[:high_contrast] ? "_high_contrast" : ""
    page.has_css?("body[data-color-mode='#{theme}'][data-#{theme}-theme='#{theme}#{contrast_suffix}']")
  end

  failure_message do |_page|
    contrast_text = options[:high_contrast] ? " with high contrast" : ""
    "expected page to have #{theme} theme#{contrast_text}"
  end

  failure_message_when_negated do |_page|
    contrast_text = options[:high_contrast] ? " with high contrast" : ""
    "expected page not to have #{theme} theme#{contrast_text}"
  end
end

RSpec::Matchers.define :have_auto_theme_config do |expected_config|
  match do |page|
    base_selector = "body[data-auto-theme-switcher-theme-value='sync_with_os']"
    return false unless page.has_css?(base_selector)

    if expected_config[:enable_auto_light_contrast]
      light_selector = "body[data-auto-theme-switcher-enable-auto-light-theme-contrast-value='true']"
      return false unless page.has_css?(light_selector)
    end

    if expected_config[:enable_auto_dark_contrast]
      dark_selector = "body[data-auto-theme-switcher-enable-auto-dark-theme-contrast-value='true']"
      return false unless page.has_css?(dark_selector)
    end

    true
  end

  failure_message do |_page|
    "expected page to have auto theme configuration: #{expected_config}"
  end
end

module ThemeTestHelpers
  def select_theme(theme)
    select theme, from: "Color mode"
    click_on "Update look and feel"
  end

  def enable_contrast_for_single_theme
    check "Increase contrast"
    click_on "Update look and feel"
  end

  def configure_auto_contrast(light: false, dark: false)
    check "Force high-contrast when in Light mode" if light
    check "Force high-contrast when in Dark mode" if dark
    click_on "Update look and feel"
  end

  def navigate_to_interface_settings
    click_on "Interface"
  end
end
