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
require_module_spec_helper

RSpec.describe "Show/Edit Document View",
               :js,
               :selenium,
               with_flag: { block_note_editor: true } do
  shared_let(:project) { create(:project) }
  shared_let(:member_role) { create(:existing_project_role, permissions: %i[view_documents manage_documents]) }
  shared_let(:member) { create(:user, member_with_roles: { project => member_role }) }

  let(:document_types) do
    %w[Specification Report].map { create(:document_type, name: it) }
  end
  let(:document) { create(:document, project:, title: "Collaborative document", type: document_types.first) }

  current_user { member }

  it "renders a collaborative document" do
    visit document_path(document)

    expect(page).to have_content("Collaborative document")

    aggregate_failures "can change document type" do
      within_test_selector("document-info-line") do
        click_button "Specification"
        click_on "Report"
        expect(page).to have_button("Report")
      end
      expect(document.reload.type).to eq(document_types[1])
    end

    aggregate_failures "can edit document content" do
      editor = FormFields::Primerized::BlockNoteEditorInput.new
      editor.fill_in_with_content("This is the new **content**.")

      expect(page).to have_content("This is the new content.")
    end
  end

  context "without view documents permission" do
    let(:user) { create(:user) }

    current_user { user }

    it "renders a not authorized message" do
      visit document_path(document)
      expect(page).to have_text("[Error 403] You are not authorized to access this page.")
    end
  end
end
