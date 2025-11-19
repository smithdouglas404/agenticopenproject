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

RSpec.describe "Document types admin", :js do
  include Flash::Expectations

  current_user { create(:admin) }
  let!(:default_document_type) { create(:document_type, is_default: true, name: "Note") }

  def within_enumeration_item(type, &)
    page.within("#documents-admin-document-types-item-component-#{type.id}", &)
  end

  it "can be managed (created, updated, deleted)" do
    visit admin_settings_document_types_path

    within_enumeration_item(default_document_type) do
      expect(page).to have_content("Note")
      expect(page).to have_content("Default")
    end

    within_test_selector("admin-document-types-subheader") do
      click_on "Add"
    end

    fill_in "Name", with: "Documentation"
    check "Default"
    click_on("Save")

    expect_and_dismiss_flash(message: "Successful update.")

    # we are redirected back to the index page
    expect(page).to have_current_path(admin_settings_document_types_path)

    new_document_type = DocumentType.last

    # The new document type is shown in the list as the default document type
    within_enumeration_item(new_document_type) do
      expect(page).to have_content("Documentation")
      expect(page).to have_content("Default")
    end

    # Since the new document type is now the default, the former default looses that flag
    within_enumeration_item(default_document_type) do
      expect(page).to have_content("Note")
      expect(page).to have_no_content("Default")
    end

    click_link "Documentation"

    fill_in "Name", with: "Report"
    click_on("Save")

    expect_and_dismiss_flash(message: "Successful update.")

    within_enumeration_item(new_document_type) do
      expect(page).to have_content("Report")
      expect(page).to have_content("Default")
    end

    expect(DocumentType).to exist(name: "Report")
    expect(DocumentType).not_to exist(name: "Documentation")

    # It allows deleting document types
    within_enumeration_item(new_document_type) do
      click_on accessible_name: "Document type actions"
      click_button("Delete")
    end

    expect_and_dismiss_flash(message: "Successful deletion.")

    expect(page).to have_no_content("Report")

    # Since the old default is deleted another is now the default.
    within_enumeration_item(default_document_type) do
      expect(page).to have_content("Note")
      expect(page).to have_no_content("Default")
    end
  end
end
