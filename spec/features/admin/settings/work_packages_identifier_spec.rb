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

RSpec.describe "Work packages identifier admin settings", :js do
  shared_let(:admin) { create(:admin) }

  before do
    with_flags(semantic_work_package_ids: true)
    login_as(admin)
  end

  let(:settings_path) { "/admin/settings/work_packages_identifier" }

  def visit_settings
    visit settings_path
    # Wait for the radio group legend to confirm the page has loaded
    expect(page).to have_css("legend", text: I18n.t("settings.work_packages.work_package_identifier"),
                                       wait: 10)
  end

  context "when no projects have problematic identifiers" do
    it "saves the setting without showing a dialog" do
      visit_settings

      click_button I18n.t("button_save")

      expect(page).to have_current_path(settings_path)
      expect(page).to have_no_dialog
    end
  end

  context "when a project has a problematic identifier" do
    shared_let(:project) { create(:project, identifier: "bad-id", name: "Bad Project") }

    context "when saving with the current numeric setting" do
      it "saves without showing the confirmation dialog" do
        visit_settings

        # The autofix section is hidden when numeric is selected
        expect(page).to have_css(
          "[data-admin--work-packages-identifier-target=autofixSection][hidden]",
          visible: :all
        )
        click_button I18n.t("button_save")

        expect(page).to have_current_path(settings_path)
        expect(page).to have_no_dialog
      end
    end

    context "when switching to alphanumeric" do
      before do
        visit_settings
        choose I18n.t("setting_work_packages_identifier_alphanumeric")
      end

      it "shows the autofix section after selecting alphanumeric" do
        expect(page).to have_css(
          "[data-admin--work-packages-identifier-target=autofixSection]:not([hidden])",
          visible: :visible
        )
      end

      it "opens the confirmation dialog when 'Autofix and save' is clicked" do
        click_button I18n.t("admin.settings.work_packages_identifier.button_autofix")

        expect(page).to have_dialog "Change work package identifiers"
      end

      it "shows the dialog heading and checkbox" do
        click_button I18n.t("admin.settings.work_packages_identifier.button_autofix")

        within_dialog "Change work package identifiers" do
          expect(page).to have_text(I18n.t("admin.settings.work_packages_identifier.dialog.heading"))
          expect(page).to have_field(
            I18n.t("admin.settings.work_packages_identifier.dialog.checkbox_label"),
            type: :checkbox
          )
        end
      end

      it "enables the confirm button only after checking the checkbox" do
        click_button I18n.t("admin.settings.work_packages_identifier.button_autofix")

        within "[role=alertdialog]" do
          confirm_text = I18n.t("admin.settings.work_packages_identifier.dialog.confirm_button")

          expect(page).to have_button(confirm_text, disabled: true)

          check I18n.t("admin.settings.work_packages_identifier.dialog.checkbox_label")

          expect(page).to have_button(confirm_text, disabled: false)
        end
      end

      it "hides the plain Save button when autofix section is visible" do
        expect(page).to have_no_button(I18n.t("button_save"))
        expect(page).to have_button(
          I18n.t("admin.settings.work_packages_identifier.button_autofix"),
          disabled: false
        )
      end
    end
  end
end
