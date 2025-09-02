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

class My::LookAndFeelForm < ApplicationForm
  include ApplicationHelper

  form do |f|
    f.select_list(
      name: :theme,
      label: I18n.t("activerecord.attributes.user_preference.theme"),
      caption: I18n.t("activerecord.attributes.user_preference.mode_guideline"),
      required: true,
      include_blank: false,
      input_width: :small,
      data: {
        action: "change->interface-account-settings#toggleCheckbox",
        "interface-account-settings-target": "modeSelect"
      }
    ) do |select|
      theme_options_for_select.each do |label, value|
        selected_value =
          if User.current.pref.theme.to_s.start_with?("sync_with_os")
            "sync_with_os"
          else
            User.current.pref.theme.to_s.sub(/_high_contrast$/, "")
          end

        select.option(
          value: value,
          label: label,
          selected: value == selected_value
        )
      end
    end

    f.check_box name: :increase_contrast,
                label: I18n.t("activerecord.attributes.user_preference.increase_contrast"),
                caption: I18n.t("activerecord.attributes.user_preference.increase_contrast_caption"),
                checked: increase_contrast_checked?,
                data: { "interface-account-settings-target": "increaseContrastCheckbox" }

    f.check_box name: :sync_with_os_light_high_contrast,
                label: I18n.t("activerecord.attributes.user_preference.sync_with_os_light_high_contrast"),
                caption: I18n.t("activerecord.attributes.user_preference.sync_with_os_light_high_contrast_caption"),
                checked: sync_with_os_light_checked?,
                data: { "interface-account-settings-target": "autoLightCheckbox" }

    f.check_box name: :sync_with_os_dark_high_contrast,
                label: I18n.t("activerecord.attributes.user_preference.sync_with_os_dark_high_contrast"),
                caption: I18n.t("activerecord.attributes.user_preference.sync_with_os_dark_high_contrast_caption"),
                checked: sync_with_os_dark_checked?,
                data: { "interface-account-settings-target": "autoDarkCheckbox" }

    f.select_list(
      name: :comments_sorting,
      label: I18n.t("activerecord.attributes.user_preference.comments_sorting"),
      required: true,
      include_blank: false,
      input_width: :small
    ) do |select|
      comment_sort_order_options.each do |theme|
        select.option(
          value: theme[1],
          label: theme[0]
        )
      end
    end

    f.check_box name: :disable_keyboard_shortcuts,
                label: I18n.t("activerecord.attributes.user_preference.disable_keyboard_shortcuts"),
                caption: I18n.t("activerecord.attributes.user_preference.disable_keyboard_shortcuts_caption_html",
                                href: OpenProject::Static::Links.links[:shortcuts][:href]).html_safe

    f.submit(name: :submit,
             label: I18n.t("activerecord.attributes.user_preference.button_update_look_and_feel"),
             scheme: :default)
  end

  def increase_contrast_checked?
    # User.current.pref.theme ends with _high_contrast
    User.current.pref.theme.to_s.end_with?("_high_contrast")
  end

  def sync_with_os_light_checked?
    %w[sync_with_os_high_contrast sync_with_os_light_high_contrast].include?(User.current.pref.theme.to_s)
  end

  # Returns true if the theme should force high-contrast in Dark mode
  def sync_with_os_dark_checked?
    %w[sync_with_os_high_contrast sync_with_os_dark_high_contrast].include?(User.current.pref.theme.to_s)
  end
end
