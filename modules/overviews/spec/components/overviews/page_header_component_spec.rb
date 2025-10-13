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

RSpec.describe Overviews::PageHeaderComponent, type: :component do
  def render_component(...)
    render_inline(described_class.new(...))
  end

  let(:workspace_type) { :project }
  let(:project) { build_stubbed(:project, name: "Too big to fail", workspace_type:) }
  let(:user) { build_stubbed(:user) }

  current_user { user }

  subject(:rendered_component) do
    with_controller_class(Overviews::OverviewsController) do
      with_request_url("/projects/identifier") do
        render_component(project:, current_user:)
      end
    end
  end

  shared_examples_for "rendering breadcrumbs" do |breadcrumbs|
    it "renders #{breadcrumbs.size} breadcrumbs", :aggregate_failures do
      expect(rendered_component).to have_navigation "Breadcrumb", class: "PageHeader-breadcrumbs" do |nav|
        expect(nav).to have_list_item count: breadcrumbs.size
        breadcrumbs.each.with_index do |breadcrumb, i|
          expect(nav).to have_list_item position: i + 1, text: breadcrumb
        end
      end
    end
  end

  describe "context bar" do
    it "renders context bar" do
      expect(rendered_component).to have_css ".PageHeader-contextBar"
    end

    it "renders current page", with_flag: { new_project_overview: true } do
      expect(rendered_component).to have_link "Project home", current: "page"
    end

    it "renders current page", with_flag: { new_project_overview: false } do
      expect(rendered_component).to have_link "Overview", current: "page"
    end
  end

  context "with the feature flag enabled", with_flag: { new_project_overview: true } do
    it "renders a Page Header (with tab nav)" do
      expect(rendered_component).to have_element "page-header", class: "PageHeader--withTabNav"
    end

    context "with Project" do
      it "renders title" do
        expect(rendered_component).to have_heading "Project home", class: "PageHeader-title"
      end

      it_behaves_like "rendering breadcrumbs", ["OpenProject", "Too big to fail", "Project home"]
    end

    context "with Portfolio" do
      let(:workspace_type) { :portfolio }

      it "renders title" do
        expect(rendered_component).to have_heading "Portfolio home", class: "PageHeader-title"
      end

      it_behaves_like "rendering breadcrumbs", ["OpenProject", "Too big to fail", "Portfolio home"]
    end

    context "with Program" do
      let(:workspace_type) { :program }

      it "renders title" do
        expect(rendered_component).to have_heading "Program home", class: "PageHeader-title"
      end

      it_behaves_like "rendering breadcrumbs", ["OpenProject", "Too big to fail", "Program home"]
    end
  end

  context "with the feature flag disabled", with_flag: { new_project_overview: false } do
    it "renders a Page Header" do
      expect(rendered_component).to have_element "page-header"
    end

    it "renders title" do
      expect(rendered_component).to have_heading "Overview", class: "PageHeader-title"
    end

    it_behaves_like "rendering breadcrumbs", ["OpenProject", "Too big to fail", "Overview"]
  end

  describe "actions" do
    it "renders actions" do
      expect(rendered_component).to have_css ".PageHeader-actions"
    end

    it "renders favorite button" do
      expect(rendered_component).to have_link class: "PageHeader-action" do |link|
        expect(link).to have_octicon :star
      end
    end

    it "renders a Primer ActionMenu (single variant)" do
      expect(rendered_component).to have_element "action-menu", "data-select-variant": "none"
    end

    context "without manage permissions" do
      it "renders action menu items", :aggregate_failures do
        expect(rendered_component).to have_menu do |menu|
          expect(menu).to have_selector :menuitem, count: 1
          expect(menu).to have_selector :menuitem, text: "Add to favorites"
        end
      end
    end

    context "with manage permissions" do
      let(:user) { build_stubbed(:admin) }

      it "renders action menu items", :aggregate_failures do
        expect(rendered_component).to have_menu do |menu|
          expect(menu).to have_selector :menuitem, count: 3
          expect(menu).to have_selector :menuitem, text: "Add to favorites"
          expect(menu).to have_selector :menuitem, text: "Manage project attributes"
          expect(menu).to have_selector :menuitem, text: "Archive project"
        end
      end
    end
  end

  describe "tab bar", with_flag: { new_project_overview: true } do
    it "renders a tab bar" do
      expect(rendered_component).to have_css ".PageHeader-tabNavBar"
    end

    it "renders 2 tabs", :aggregate_failures do
      expect(rendered_component).to have_list class: "tabnav-tabs" do |list|
        expect(list).to have_list_item count: 2
        expect(list).to have_list_item "Overview"
        expect(list).to have_list_item "Dashboard"
      end
    end

    it "renders Overview tab link", :aggregate_failures do
      expect(rendered_component).to have_link "Overview" do |link|
        expect(link).to have_octicon :"op-view-split"
      end
    end

    it "renders Dashboard tab link", :aggregate_failures do
      expect(rendered_component).to have_link "Dashboard" do |link|
        expect(link).to have_octicon :"op-view-list"
      end
    end
  end
end
