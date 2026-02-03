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
    it "shows Open fullscreen link (full page)" do
      render_component

      expect(page).to have_text(I18n.t(:"js.button_open_fullscreen"))
      expect(page).to have_octicon(:"screen-full")
    end

    it "shows a divider before move options" do
      render_component

      expect(page).to have_css(".ActionList-sectionDivider")
    end
  end

  describe "move menu items" do
    it "shows Move to top item with move-to-top icon" do
      render_component

      expect(page).to have_text(I18n.t(:label_sort_highest))
      expect(page).to have_octicon(:"move-to-top")
    end

    it "shows Move up item with chevron-up icon" do
      render_component

      expect(page).to have_text(I18n.t(:label_sort_higher))
      expect(page).to have_octicon(:"chevron-up")
    end

    it "shows Move down item with chevron-down icon" do
      render_component

      expect(page).to have_text(I18n.t(:label_sort_lower))
      expect(page).to have_octicon(:"chevron-down")
    end

    it "shows Move to bottom item with move-to-bottom icon" do
      render_component

      expect(page).to have_text(I18n.t(:label_sort_lowest))
      expect(page).to have_octicon(:"move-to-bottom")
    end
  end

  describe "position logic" do
    context "when item is first (position=1)" do
      it "disables Move to top and Move up" do
        render_component(position: 1, max_position: 3)

        # Move to top should be disabled
        move_to_top = page.find("li", text: I18n.t(:label_sort_highest))
        expect(move_to_top[:class]).to include("ActionListItem--disabled")

        # Move up should be disabled
        move_up = page.find("li", text: I18n.t(:label_sort_higher))
        expect(move_up[:class]).to include("ActionListItem--disabled")
      end

      it "enables Move down and Move to bottom" do
        render_component(position: 1, max_position: 3)

        # Move down should be enabled
        move_down = page.find("li", text: I18n.t(:label_sort_lower))
        expect(move_down[:class]).not_to include("ActionListItem--disabled")

        # Move to bottom should be enabled
        move_to_bottom = page.find("li", text: I18n.t(:label_sort_lowest))
        expect(move_to_bottom[:class]).not_to include("ActionListItem--disabled")
      end
    end

    context "when item is last (position=max)" do
      it "disables Move down and Move to bottom" do
        render_component(position: 3, max_position: 3)

        # Move down should be disabled
        move_down = page.find("li", text: I18n.t(:label_sort_lower))
        expect(move_down[:class]).to include("ActionListItem--disabled")

        # Move to bottom should be disabled
        move_to_bottom = page.find("li", text: I18n.t(:label_sort_lowest))
        expect(move_to_bottom[:class]).to include("ActionListItem--disabled")
      end

      it "enables Move to top and Move up" do
        render_component(position: 3, max_position: 3)

        # Move to top should be enabled
        move_to_top = page.find("li", text: I18n.t(:label_sort_highest))
        expect(move_to_top[:class]).not_to include("ActionListItem--disabled")

        # Move up should be enabled
        move_up = page.find("li", text: I18n.t(:label_sort_higher))
        expect(move_up[:class]).not_to include("ActionListItem--disabled")
      end
    end

    context "when item is in the middle" do
      it "enables all move options" do
        render_component(position: 2, max_position: 3)

        expect(page.find("li", text: I18n.t(:label_sort_highest))[:class]).not_to include("ActionListItem--disabled")
        expect(page.find("li", text: I18n.t(:label_sort_higher))[:class]).not_to include("ActionListItem--disabled")
        expect(page.find("li", text: I18n.t(:label_sort_lower))[:class]).not_to include("ActionListItem--disabled")
        expect(page.find("li", text: I18n.t(:label_sort_lowest))[:class]).not_to include("ActionListItem--disabled")
      end
    end

    context "when there is only one item (position=1, max=1)" do
      it "disables all move options" do
        render_component(position: 1, max_position: 1)

        expect(page.find("li", text: I18n.t(:label_sort_highest))[:class]).to include("ActionListItem--disabled")
        expect(page.find("li", text: I18n.t(:label_sort_higher))[:class]).to include("ActionListItem--disabled")
        expect(page.find("li", text: I18n.t(:label_sort_lower))[:class]).to include("ActionListItem--disabled")
        expect(page.find("li", text: I18n.t(:label_sort_lowest))[:class]).to include("ActionListItem--disabled")
      end
    end
  end
end
