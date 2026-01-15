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

require_relative "../support/pages/meetings/show"

RSpec.describe "Meeting outcomes work package linking", :js do
  include Components::Autocompleter::NgSelectAutocompleteHelpers

  shared_let(:project) { create(:project, enabled_module_names: %w[meetings work_package_tracking]) }
  shared_let(:user) do
    create :user,
           lastname: "First",
           preferences: { time_zone: "Etc/UTC" },
           member_with_permissions: { project => %i[view_meetings manage_agendas manage_outcomes view_work_packages] }
  end
  shared_let(:meeting) do
    create :meeting,
           project:,
           start_time: "2024-12-31T13:30:00Z",
           duration: 1.5,
           author: user
  end
  shared_let(:meeting_agenda_item) { create(:meeting_agenda_item, meeting:) }
  shared_let(:work_package1) do
    create(:work_package,
           project:,
           subject: "Important task")
  end
  shared_let(:work_package2) do
    create(:work_package,
           project:,
           subject: "Another task")
  end

  let(:current_user) { user }
  let(:state) { :in_progress }
  let(:show_page) { Pages::Meetings::Show.new(meeting) }

  before do
    meeting.update!(state:)
    login_as current_user
  end

  context "when a user has the necessary permissions" do
    context "when the meeting is 'in progress'" do
      it "shows a dropdown with two outcome options" do
        show_page.visit!

        within("#meeting-agenda-items-outcomes-new-button-component-#{meeting_agenda_item.id}") do
          click_on "Outcome"

          expect(page).to have_text("Write outcome")
          expect(page).to have_text("Existing work package")
        end
      end

      it "can link an existing work package as an outcome" do
        show_page.visit!

        item = MeetingAgendaItem.find(meeting_agenda_item.id)

        within("#meeting-agenda-items-outcomes-new-button-component-#{item.id}") do
          click_on "Outcome"
        end
        page.find("a", text: "Existing work package", wait: 3).click

        expect(page).to have_css("#meeting-agenda-items-outcomes-work-package-form-component-#{item.id}")
        select_autocomplete(find_test_selector("op-agenda-item-outcome-wp-autocomplete"),
                            query: "Important",
                            results_selector: "body")
        within("#meeting-agenda-items-outcomes-work-package-form-component-#{item.id}") do
          click_on "Add"
        end

        show_page.in_outcome_component(item) do
          expect(page).to have_text(work_package1.type.name)
          expect(page).to have_text("##{work_package1.id}")
          expect(page).to have_text(work_package1.status.name)
          expect(page).to have_link(work_package1.subject)
        end
      end

      it "can delete a work package outcome" do
        outcome = create(:meeting_outcome,
                         meeting_agenda_item:,
                         work_package: work_package1,
                         kind: :work_package)

        show_page.visit!

        item = MeetingAgendaItem.find(meeting_agenda_item.id)

        show_page.in_outcome_component(item) do
          expect(page).to have_text(work_package1.subject)
          show_page.select_outcome_action "Remove outcome"
        end

        expect(page).to have_no_text(work_package1.subject)
        expect { outcome.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "can create both text and work package outcomes for the same agenda item" do
        show_page.visit!

        item = MeetingAgendaItem.find(meeting_agenda_item.id)

        within("#meeting-agenda-items-outcomes-new-button-component-#{item.id}") do
          click_on "Outcome"
        end
        page.find("a", text: "Write outcome", wait: 3).click

        field = TextEditorField.new(page, "Outcome", selector: test_selector("meeting-outcome-input-for-#{item.id}"))
        field.expect_active!
        field.set_value "This is a text outcome"
        click_on "Save"

        show_page.in_outcome_component(item) do
          show_page.expect_outcome "This is a text outcome"
        end

        within("#meeting-agenda-items-outcomes-new-button-component-#{item.id}") do
          click_on "Outcome"
        end
        page.find("a", text: "Existing work package", wait: 3).click

        select_autocomplete(find_test_selector("op-agenda-item-outcome-wp-autocomplete"),
                            query: "Another",
                            results_selector: "body")

        within("#meeting-agenda-items-outcomes-work-package-form-component-#{item.id}") do
          click_on "Add"
        end

        show_page.in_outcome_component(item) do
          show_page.expect_outcome "This is a text outcome"
          expect(page).to have_link(work_package2.subject)

          expect(page).to have_text("Outcome 1")
          expect(page).to have_text("Outcome 2")
        end
      end

      it "can cancel adding a work package outcome" do
        show_page.visit!

        item = MeetingAgendaItem.find(meeting_agenda_item.id)

        within("#meeting-agenda-items-outcomes-new-button-component-#{item.id}") do
          click_on "Outcome"
        end
        page.find("a", text: "Existing work package", wait: 3).click

        expect(page).to have_css("#meeting-agenda-items-outcomes-work-package-form-component-#{item.id}")

        # Close the autocompleter dropdown that opens automatically
        page.find("#meeting-agenda-items-outcomes-work-package-form-component-#{item.id} .ng-input input").send_keys(:escape)

        within("#meeting-agenda-items-outcomes-work-package-form-component-#{item.id}") do
          click_on "Cancel"
        end

        # Form should be hidden, button should be back
        expect(page).to have_no_css("#meeting-agenda-items-outcomes-work-package-form-component-#{item.id}")
        expect(page).to have_css("#meeting-agenda-items-outcomes-new-button-component-#{item.id}")
      end
    end
  end

  context "when the work package is from another project" do
    let!(:other_project) { create(:project, enabled_module_names: %w[work_package_tracking]) }
    let!(:other_wp) { create(:work_package, project: other_project, author: user, subject: "Private work package") }
    let!(:role) { create(:project_role, permissions: %w[view_work_packages]) }
    let!(:membership) { create(:member, principal: user, project: other_project, roles: [role]) }
    let!(:other_user) do
      create(:user,
             lastname: "Other",
             member_with_permissions: { project => %i[view_meetings] })
    end
    let!(:outcome) do
      create(:meeting_outcome,
             meeting_agenda_item:,
             work_package: other_wp,
             kind: :work_package)
    end

    it "shows undisclosed message for users without access" do
      show_page.visit!

      show_page.in_outcome_component(meeting_agenda_item) do
        expect(page).to have_text("Private work package")
      end

      login_as(other_user)

      show_page.visit!

      show_page.in_outcome_component(meeting_agenda_item) do
        expect(page).to have_no_text("Private work package")
        expect(page).to have_text(I18n.t(:label_agenda_item_undisclosed_wp, id: other_wp.id))
      end
    end
  end

  context "when the linked work package is deleted" do
    let!(:work_package_to_delete) { create(:work_package, project:, subject: "To be deleted") }
    let!(:outcome) do
      create(:meeting_outcome,
             meeting_agenda_item:,
             work_package: work_package_to_delete,
             kind: :work_package)
    end

    it "shows deleted work package message after deletion" do
      show_page.visit!

      show_page.in_outcome_component(meeting_agenda_item) do
        expect(page).to have_text("To be deleted")
      end

      work_package_to_delete.destroy!
      show_page.visit!

      show_page.in_outcome_component(meeting_agenda_item) do
        expect(page).to have_no_text("To be deleted")
        expect(page).to have_text(I18n.t(:label_agenda_item_deleted_wp))
      end
    end
  end

  context "when the meeting is not in progress" do
    let(:state) { :open }
    let(:outcome) do
      create(:meeting_outcome,
             meeting_agenda_item:,
             work_package: work_package1,
             kind: :work_package)
    end

    before do
      outcome
      show_page.visit!
    end

    it "can view work package outcomes but not add or edit them" do
      show_page.in_outcome_component(meeting_agenda_item) do
        expect(page).to have_text(work_package1.subject)
      end

      show_page.expect_no_outcome_button

      show_page.expect_no_outcome_actions
    end
  end
end
