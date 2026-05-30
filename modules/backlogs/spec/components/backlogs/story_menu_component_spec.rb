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

# The component itself renders only the deferred menu shell — a kebab
# trigger and an include-fragment placeholder. The actual menu items
# (Open details, Open fullscreen, divider, four Move-to actions) are
# rendered server-side by RbStoriesController#menu and fetched by Primer
# ActionMenu on first hover/click via the `src:` attribute. Item-level
# behaviour is covered by the controller / view specs for #menu, not
# here.
RSpec.describe Backlogs::StoryMenuComponent, type: :component do
  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:type_task) { create(:type_task) }
  shared_let(:default_status) { create(:default_status) }
  shared_let(:default_priority) { create(:default_priority) }
  shared_let(:user) { create(:admin) }
  current_user { user }

  let(:project) { create(:project, types: [type_feature, type_task]) }
  let(:sprint) { create(:sprint, project:, name: "Sprint 1", start_date: Date.yesterday, effective_date: Date.tomorrow) }
  let(:story) do
    create(:story,
           subject: "Test Story",
           project:,
           type: type_feature,
           status: default_status,
           priority: default_priority,
           story_points: 5,
           position: 2,
           version: sprint)
  end

  before do
    allow(Setting)
      .to receive(:plugin_openproject_backlogs)
      .and_return("story_types" => [type_feature.id.to_s], "task_type" => type_task.id.to_s)
  end

  def render_component
    render_inline(described_class.new(story:, sprint:, current_user: user))
  end

  describe "deferred shell" do
    it "renders an action-menu element" do
      render_component

      expect(page).to have_css("action-menu")
    end

    it "renders the kebab trigger button" do
      render_component

      expect(page).to have_octicon(:"kebab-horizontal")
    end

    it "points the action-menu at the per-story menu URL via include-fragment" do
      render_component

      expected_src = "/projects/#{project.identifier}/sprints/#{sprint.id}/stories/#{story.id}/menu"
      expect(page).to have_css("include-fragment[src$='#{expected_src}']")
    end
  end

  describe "items not rendered inline" do
    # These are the items the server returns from RbStoriesController#menu —
    # they must NOT be present in the inline component output, otherwise the
    # CPU regression from PR #20 returns.
    it "does not render Open details / Open fullscreen inline" do
      render_component

      expect(page).to have_no_text(I18n.t(:"js.button_open_details"))
      expect(page).to have_no_text(I18n.t(:"js.button_open_fullscreen"))
    end

    it "does not render any Move-to items inline" do
      render_component

      expect(page).to have_no_text(I18n.t(:label_sort_highest))
      expect(page).to have_no_text(I18n.t(:label_sort_higher))
      expect(page).to have_no_text(I18n.t(:label_sort_lower))
      expect(page).to have_no_text(I18n.t(:label_sort_lowest))
    end
  end
end
