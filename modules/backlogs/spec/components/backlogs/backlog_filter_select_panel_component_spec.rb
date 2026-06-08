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

RSpec.describe Backlogs::BacklogFilterSelectPanelComponent, type: :component do
  shared_let(:project) { create(:project) }
  shared_let(:user) { create(:admin) }

  current_user { user }

  def render_component(field_name:, filters: Backlogs::BacklogFilters.new(nil, nil, false))
    RequestStore.store[:backlog_filters] = filters
    render_inline(described_class.new(project:, field_name:))
  end

  describe "sprint panel" do
    shared_let(:sprint1) { create(:sprint, project:, name: "Alpha Sprint") }
    shared_let(:sprint2) { create(:sprint, project:, name: "Beta Sprint") }

    it "shows 'Sprints' as the button label" do
      render_component(field_name: :sprint_ids)
      expect(page).to have_button("Sprints")
    end

    it "renders all sprints as items" do
      render_component(field_name: :sprint_ids)
      expect(page).to have_text("Alpha Sprint")
      expect(page).to have_text("Beta Sprint")
    end

    it "marks selected sprints as active" do
      filters = Backlogs::BacklogFilters.new(nil, [sprint1.id], false)
      render_component(field_name: :sprint_ids, filters:)
      expect(page).to have_css("[aria-selected='true']", text: "Alpha Sprint")
      expect(page).to have_css("[aria-selected='false']", text: "Beta Sprint")
    end
  end

  describe "bucket panel" do
    shared_let(:bucket1) { create(:backlog_bucket, project:, name: "Ideas") }
    shared_let(:bucket2) { create(:backlog_bucket, project:, name: "Backlog") }

    it "shows 'Backlog buckets' as the button label" do
      render_component(field_name: :bucket_ids)
      expect(page).to have_button("Backlog buckets")
    end

    it "renders all buckets as items" do
      render_component(field_name: :bucket_ids)
      expect(page).to have_text("Ideas")
      expect(page).to have_text("Backlog")
    end

    it "marks selected buckets as active" do
      filters = Backlogs::BacklogFilters.new([bucket2.id], nil, false)
      render_component(field_name: :bucket_ids, filters:)
      expect(page).to have_css("[aria-selected='false']", text: "Ideas")
      expect(page).to have_css("[aria-selected='true']", text: "Backlog")
    end
  end

  describe "hidden filter fields" do
    it "passes through sprint_ids when rendering the bucket panel" do
      render_component(field_name: :bucket_ids,
                       filters: Backlogs::BacklogFilters.new(nil, [""], false))
      expect(page).to have_css("input[name='sprint_ids[]'][value='']", visible: :all)
    end

    it "passes through bucket_ids when rendering the sprint panel" do
      render_component(field_name: :sprint_ids,
                       filters: Backlogs::BacklogFilters.new([""], nil, false))
      expect(page).to have_css("input[name='bucket_ids[]'][value='']", visible: :all)
    end

    it "expands array values into multiple hidden inputs" do
      render_component(field_name: :sprint_ids,
                       filters: Backlogs::BacklogFilters.new([1, 2], nil, false))
      expect(page).to have_css("input[name='bucket_ids[]'][value='1']", visible: :all)
      expect(page).to have_css("input[name='bucket_ids[]'][value='2']", visible: :all)
    end
  end
end
