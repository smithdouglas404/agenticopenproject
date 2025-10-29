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

require_relative "support/documents_index_page"

RSpec.describe "Delete Document",
               :js,
               :selenium do
  shared_let(:project) { create(:project) }
  shared_let(:member_role_read_only) { create(:existing_project_role, permissions: [:view_documents]) }
  shared_let(:member_role_manage) { create(:existing_project_role, permissions: %i[view_documents manage_documents]) }
  shared_let(:member) { create(:user, member_with_roles: { project => member_role_read_only }) }
  shared_let(:manager) { create(:user, member_with_roles: { project => member_role_manage }) }
  shared_let(:documents) { create_list(:document, 3, project:) }

  let(:index_page) { Documents::Pages::ListPage.new(project) }
  let(:delete_candidate) { documents.first }

  context "with documents manager role" do
    current_user { manager }

    it "allows deleting documents" do
      index_page.visit!

      index_page.expect_documents_listed(documents)

      click_on delete_candidate.title
      expect(page).to have_current_path(document_path(delete_candidate))
      accept_alert { click_on "Delete" }

      expect(page).to have_content("Successful deletion.")
      expect(page).to have_current_path(project_documents_path(project))
      index_page.expect_documents_listed(documents.drop(1))
    end

    context "when deletion fails" do
      before do
        allow_any_instance_of(Document).to receive(:destroy).and_return(false) # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(Document).to receive_message_chain(:errors, :full_messages) # rubocop:disable RSpec/AnyInstance, RSpec/MessageChain
          .and_return(["Deletion failed due to some error"])
      end

      it "shows an error message" do
        index_page.visit!

        index_page.expect_documents_listed(documents)

        click_on delete_candidate.title
        expect(page).to have_current_path(document_path(delete_candidate))
        accept_alert { click_on "Delete" }

        expect(page).to have_content("Deletion failed due to some error")
        expect(page).to have_current_path(project_documents_path(project))
      end
    end
  end

  context "without manage documents permission" do
    current_user { member }

    it "does not allow deleting documents" do
      index_page.visit!

      index_page.expect_documents_listed(documents)
      click_on delete_candidate.title

      expect(page).to have_current_path(document_path(delete_candidate))
      expect(page).to have_no_button("Delete")
    end
  end
end
