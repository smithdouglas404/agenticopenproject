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

RSpec.describe Backlogs::StoryMenuComponent, type: :component do
  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:type_task) { create(:type_task) }
  shared_let(:default_status) { create(:default_status) }
  shared_let(:default_priority) { create(:default_priority) }
  shared_let(:user) { create(:admin) }
  current_user { user }

  let(:project) { create(:project, types: [type_feature, type_task]) }
  let(:sprint) { create(:sprint, project:, name: "Sprint 1", start_date: Date.yesterday, effective_date: Date.tomorrow) }
  let(:position) { 2 }
  let(:max_position) { 3 }
  let(:story) do
    create(:story,
           subject: "Test Story",
           project:,
           type: type_feature,
           status: default_status,
           priority: default_priority,
           story_points: 5,
           position:,
           version: sprint)
  end

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return("story_types" => [type_feature.id.to_s], "task_type" => type_task.id.to_s)
  end

  def render_component(position: 2, max_position: 3)
    story.update!(position:)
    render_inline(described_class.new(story:, sprint:, max_position:, current_user: user))
  end

  describe "standard items" do
    it "shows Open details link (split view)" do
      render_component

      expect(page).to have_text(I18n.t(:"js.button_open_details"))
      expect(page).to have_octicon(:"op-view-split")
    end

    it "shows Open fullscreen link (full page)" do
      render_component

      expect(page).to have_text(I18n.t(:"js.button_open_fullscreen"))
      expect(page).to have_octicon(:"screen-full")
    end

    it "does not render a divider since the move-items section was removed" do
      render_component

      expect(page).to have_no_css(".ActionList-sectionDivider")
    end
  end

  # Move-to-top/up/down/bottom items are intentionally not rendered as part
  # of the per-row menu. See the comment in story_menu_component.html.erb —
  # they were the dominant contributor to the initial-render CPU spike on
  # columns with many items. Drag-drop covers reorder for mouse/touch.
  describe "move menu items (intentionally absent)" do
    it "does not render Move to top" do
      render_component

      expect(page).to have_no_text(I18n.t(:label_sort_highest))
      expect(page).to have_no_octicon(:"move-to-top")
    end

    it "does not render Move up" do
      render_component

      expect(page).to have_no_text(I18n.t(:label_sort_higher))
      expect(page).to have_no_octicon(:"chevron-up")
    end

    it "does not render Move down" do
      render_component

      expect(page).to have_no_text(I18n.t(:label_sort_lower))
      expect(page).to have_no_octicon(:"chevron-down")
    end

    it "does not render Move to bottom" do
      render_component

      expect(page).to have_no_text(I18n.t(:label_sort_lowest))
      expect(page).to have_no_octicon(:"move-to-bottom")
    end

    it "renders no move-items regardless of position in the column" do
      [[1, 3], [2, 3], [3, 3], [1, 1]].each do |position, max|
        render_component(position:, max_position: max)

        expect(page).to have_no_text(I18n.t(:label_sort_highest))
        expect(page).to have_no_text(I18n.t(:label_sort_higher))
        expect(page).to have_no_text(I18n.t(:label_sort_lower))
        expect(page).to have_no_text(I18n.t(:label_sort_lowest))
      end
    end
  end
end
