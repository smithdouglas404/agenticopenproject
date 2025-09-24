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

RSpec.describe "Enterprise token", :js do
  include Redmine::I18n

  shared_let(:admin) { create(:admin) }

  describe "EnterpriseToken management" do
    before do
      login_as admin
      visit enterprise_tokens_path
    end

    it "shows a teaser page and has a button to add a token with a dialog" do
      expect(page).to have_link("Start free trial")

      expect(page).to have_button("Add Enterprise token")
      click_button "Add Enterprise token"

      expect(page).to have_dialog("Add Enterprise token")
      expect(page).to have_field("Type support token text", type: "textarea")
    end

    context "with invalid input" do
      it "shows an error message" do
        click_button "Add Enterprise token"
        fill_in "Type support token text", with: "foobar"
        click_button "Add"

        # The dialog is still open with an error message on token field
        expect(page).to have_dialog("Add Enterprise token")
        validation_error = "Enterprise support token can't be read. Are you sure it is a support token?"
        expect(page).to have_field("Type support token text", validation_error:)
      end
    end

    context "with valid input" do
      let(:token_object) do
        OpenProject::Token.new.tap do |token|
          token.subscriber = "Foobar"
          token.mail = "foo@example.org"
          token.starts_at = Date.current
          token.expires_at = nil
          token.domain = Setting.host_name
        end
      end

      before do
        allow(OpenProject::Token).to receive(:import).and_return(token_object)
      end

      it "allows token import flow" do
        click_button "Add Enterprise token"
        fill_in "Type support token text", with: "foobar"
        click_button "Add"

        expect(page).to have_text("Quick feature overview")
        expect(page).to have_css("#enterprise-trial-welcome-dialog video")
        page.find('[data-close-dialog-id="enterprise-trial-welcome-dialog"]').click

        # Table headers
        [
          "Subscription",
          "Active users",
          "Domain",
          "Dates"
        ].each do |attribute|
          expect(page).to have_text(attribute)
        end

        # Token values
        [
          "Enterprise Plan\nFoobar",
          "Unlimited",
          Setting.host_name,
          "#{format_date(Date.current)} – Unlimited"
        ].each do |attribute|
          expect(page).to have_text(attribute)
        end

        # Token is stored in the database
        expect(EnterpriseToken.last.encoded_token).to eq("foobar")

        # Remove token
        click_on "more-button"
        find(:menuitem, "Delete").click
        wait_for_network_idle

        # Expect deletion modal
        expect(page).to have_dialog("Delete enterprise token")
        within_dialog("Delete enterprise token") do
          click_button "Delete"
        end

        # Token deleted
        expect_and_dismiss_flash(message: I18n.t(:notice_successful_delete))
        expect(EnterpriseToken.all).to be_empty
      end

      it "cannot import same token twice" do
        click_button "Add Enterprise token"
        fill_in "Type support token text", with: "foobar"
        click_button "Add"

        expect(page).to have_text("Quick feature overview")
        expect(page).to have_css("#enterprise-trial-welcome-dialog video")
        page.find('[data-close-dialog-id="enterprise-trial-welcome-dialog"]').click

        click_button "Add Enterprise token"
        fill_in "Type support token text", with: "foobar"
        click_button "Add"

        # The dialog is still open with an error message on token field
        expect(page).to have_dialog("Add Enterprise token")
        validation_error = "This token has already been added."
        expect(page).to have_field("Type support token text", validation_error:)

        # Try importing with blank spaces and newlines before and after
        fill_in "Type support token text", with: " \nfoobar \n"
        click_button "Add"

        # The dialog is still open with an error message on token field
        expect(page).to have_dialog("Add Enterprise token")
        validation_error = "This token has already been added."
        expect(page).to have_field("Type support token text", validation_error:)
      end
    end
  end
end
