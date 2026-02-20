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
require_relative "../../support/pages/backlogs"

RSpec.describe "Create", :js do
  let(:project) { create(:project) }
  let(:all_permissions) { %i[view_master_backlog view_work_packages create_sprints] }
  let(:permissions) { all_permissions }
  let(:user) do
    create(:user, member_with_permissions: { project => permissions })
  end
  let(:backlogs_page) { Pages::Backlogs.new(project) }

  let(:story_type) do
    create(:type_feature)
  end
  let(:story_type2) do
    type = create(:type)

    project.types << type

    type
  end
  let(:inactive_story_type) do
    create(:type)
  end

  let(:task_type) do
    type = create(:type_task)
    project.types << type

    type
  end

  before do
    login_as(user)

    # Legacy backlogs module requires type configuration
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
            .and_return("story_types" => [story_type.id.to_s,
                                          story_type2.id.to_s,
                                          inactive_story_type.id.to_s],
                        "task_type" => task_type.id.to_s)

    backlogs_page.visit!
  end

  context "with the feature flag active", with_flag: { scrum_projects: true } do
    context "with the 'create_sprints' permissions" do
      before do
        new_sprint_button = page.find_test_selector("op-sprints--new-sprint-button")
        new_sprint_button&.click
      end

      let(:start_date) { Date.new(2025, 10, 5) }
      let(:start_date_fmt) { start_date.strftime("%Y-%m-%d") }
      let(:finish_date) { Date.new(2025, 10, 20) }
      let(:finish_date_fmt) { finish_date.strftime("%Y-%m-%d") }

      it "allows creating a new sprint" do
        within_dialog "New sprint" do
          page.fill_in "Sprint name", with: "My first sprint"
          page.fill_in "Start date", with: start_date_fmt
          page.fill_in "Finish date", with: finish_date_fmt

          click_on "Save"
        end

        sprint = project.reload.sprints.last
        expect(sprint).to be_present
        expect(sprint.name).to eq "My first sprint"
        expect(sprint.start_date).to eq start_date
        expect(sprint.finish_date).to eq finish_date
      end

      it "previews the sprint duration when changing the dates" do
        within_dialog "New sprint" do
          expect(page).to have_field "Duration", with: "", readonly: true

          page.fill_in "Start date", with: start_date_fmt
          page.fill_in "Finish date", with: finish_date_fmt

          expect(page).to have_field "Duration", with: "16 days", readonly: true
        end
      end

      describe "validations" do
        let(:too_early_finish_date) { start_date - 1.day }

        it "validates required fields are present" do
          within_dialog "New sprint" do
            page.fill_in "Sprint name", with: ""

            click_on "Save"

            expect(page).to have_field "Sprint name", validation_error: "can't be blank"
            expect(page).to have_field "Start date", validation_error: "can't be blank"
            expect(page).to have_field "Finish date", validation_error: "can't be blank"
          end
        end

        it "validates finish date is not before start date" do
          within_dialog "New sprint" do
            page.fill_in "Start date", with: start_date_fmt
            page.fill_in "Finish date", with: too_early_finish_date.strftime("%Y-%m-%d")

            # Shows duration as zero if finish date is before start date:
            expect(page).to have_field "Duration", with: "0 days", readonly: true

            click_on "Save"

            expect(page).to have_field("Finish date",
                                       validation_error: "must be greater than or equal to #{start_date_fmt}")
          end
        end
      end

      describe "proposed sprint names" do
        it "prefilled with 'Sprint 1' if there are no previous sprints" do
          within_dialog "New sprint" do
            expect(page).to have_field "Sprint name *", with: "Sprint 1", required: true, focused: true
          end
        end

        context "with a previous sprint" do
          before do
            create(:agile_sprint, name: "Be ambitious 42", project:)

            backlogs_page.visit!
            new_sprint_button = page.find_test_selector("op-sprints--new-sprint-button")
            new_sprint_button.click
          end

          it "offers the next sprint name with a number increment" do
            within_dialog "New sprint" do
              expect(page).to have_field "Sprint name *", with: "Be ambitious 43"
            end
          end
        end
      end
    end

    context "without the necessary permissions" do
      let(:permissions) { all_permissions - [:create_sprints] }

      it "is missing the 'new sprint' button" do
        expect(page).not_to have_test_selector("op-sprints--new-sprint-button")
      end
    end
  end

  context "with the feature flag inactive" do
    it "is missing the 'new sprint' button" do
      expect(page).not_to have_test_selector("op-sprints--new-sprint-button")
    end
  end
end
