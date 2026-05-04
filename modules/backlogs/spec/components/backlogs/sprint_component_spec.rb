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

require "rails_helper"

RSpec.describe Backlogs::SprintComponent, type: :component do
  include Rails.application.routes.url_helpers

  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:type_task) { create(:type_task) }
  shared_let(:default_status) { create(:default_status) }
  shared_let(:default_priority) { create(:default_priority) }
  shared_let(:user) { create(:admin) }
  current_user { user }

  let(:project) { create(:project, types: [type_feature, type_task]) }
  let(:sprint) { create(:agile_sprint, project:, name: "Sprint 1", start_date: Date.yesterday, finish_date: Date.tomorrow) }

  def render_component
    render_inline(described_class.new(sprint:, project:, current_user: user))
  end

  describe "rendering" do
    context "with stories" do
      let!(:story1) do
        create(:work_package,
               project:,
               type: type_feature,
               status: default_status,
               priority: default_priority,
               story_points: 5,
               position: 1,
               sprint: sprint)
      end
      let!(:story2) do
        create(:work_package,
               project:,
               type: type_feature,
               status: default_status,
               priority: default_priority,
               story_points: 3,
               position: 2,
               sprint: sprint)
      end

      it "renders a Primer::Beta::BorderBox" do
        render_component

        expect(page).to have_css(".Box")
      end

      it "has the sprint ID in the DOM id" do
        render_component

        expect(page).to have_css(".Box#agile_sprint_#{sprint.id}")
      end

      it "renders SprintHeaderComponent in header" do
        render_component

        expect(page).to have_css(".Box-header h3", text: "Sprint 1")
      end

      it "renders a stable id on the sprint header" do
        render_component

        expect(page).to have_element(:div, class: "Box-header", id: /\Aagile_sprint_#{sprint.id}_header\z/)
      end

      it "renders StoryComponent for each story" do
        render_component

        expect(page).to have_css(".Box-row", count: 2) # 2 stories
        expect(page).to have_text(story1.subject)
        expect(page).to have_text(story2.subject)
      end

      it "has drop target data attributes" do
        render_component

        box = page.find(".Box")
        expect(box["data-generic-drag-and-drop-target"]).to eq("container")
        expect(box["data-target-container-accessor"]).to eq(":scope > ul")
        expect(box["data-target-id"]).to eq("sprint:#{sprint.id}")
        expect(box["data-target-allowed-drag-type"]).to eq("story")
      end

      it "has draggable data attributes on story rows" do
        render_component

        story_row = page.find(".Box-row[id='work_package_#{story1.id}']")
        expect(story_row["data-draggable-id"]).to eq(story1.id.to_s)
        expect(story_row["data-draggable-type"]).to eq("story")
        expected_path = move_project_backlogs_work_package_path(project, sprint_id: sprint.id, id: story1.id)
        expect(story_row["data-drop-url"]).to end_with(expected_path)
      end

      context "when params[:all] is true" do
        before { vc_test_controller.params[:all] = "1" }

        it "includes the all param on story drop URLs" do
          render_component

          expect(page).to have_css(%(.Box-row#work_package_#{story1.id}[data-drop-url*="all=1"]))
        end
      end

      it "renders story rows with proper classes" do
        render_component

        story_row = page.find(".Box-row[id='work_package_#{story1.id}']")
        expect(story_row[:class]).to include("Box-row--hover-blue")
        expect(story_row[:class]).to include("Box-row--focus-gray")
        expect(story_row[:class]).to include("Box-row--clickable")
      end
    end

    context "when the user lacks the manage_sprint_items permission" do
      let(:role) { create(:project_role, permissions: %i[view_sprints view_work_packages]) }
      let(:user) { create(:user, member_with_roles: { project => role }) }
      let!(:story1) do
        create(:work_package,
               project:,
               type: type_feature,
               status: default_status,
               priority: default_priority,
               story_points: 5,
               position: 1,
               sprint: sprint)
      end

      it "does not mark story rows as draggable" do
        render_component

        story_row = page.find(".Box-row[id='work_package_#{story1.id}']")
        expect(story_row[:class]).to include("Box-row--hover-blue", "Box-row--focus-gray",
                                             "Box-row--clickable")
        expect(story_row[:class]).not_to include("Box-row--draggable")
        expect(story_row["data-draggable-id"]).to be_nil
        expect(story_row["data-draggable-type"]).to be_nil
        expect(story_row["data-drop-url"]).to be_nil
      end
    end

    context "without stories" do
      let(:rendered_component) { render_component }

      it_behaves_like "rendering Blank Slate", heading: "Sprint 1 is empty"
    end
  end
end
