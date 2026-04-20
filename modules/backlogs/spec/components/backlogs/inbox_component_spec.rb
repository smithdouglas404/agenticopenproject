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

class Backlogs::BacklogListProbeComponent < ApplicationComponent
  def initialize(project:, inbox_work_packages:, sprints:, stories_by_sprint_id:,
                 active_sprint_ids:, show_all_backlog:, current_user:)
    super()

    @project = project
    @inbox_work_packages = inbox_work_packages
    @sprints = sprints
    @stories_by_sprint_id = stories_by_sprint_id
    @active_sprint_ids = active_sprint_ids
    @show_all_backlog = show_all_backlog
    @current_user = current_user
  end

  def call
    seed_view_context
    render partial: "backlogs/backlog/backlog_list", layout: false
  end

  private

  attr_reader :project, :inbox_work_packages, :sprints, :stories_by_sprint_id,
              :active_sprint_ids, :show_all_backlog, :current_user

  def seed_view_context
    current_user_value = current_user
    show_all_backlog_value = show_all_backlog

    view_context.instance_variable_set(:@project, project)
    view_context.instance_variable_set(:@inbox_work_packages, inbox_work_packages)
    view_context.instance_variable_set(:@sprints, sprints)
    view_context.instance_variable_set(:@stories_by_sprint_id, stories_by_sprint_id)
    view_context.instance_variable_set(:@active_sprint_ids, active_sprint_ids)

    view_context.define_singleton_method(:show_all_backlog) { show_all_backlog_value }
    view_context.define_singleton_method(:allow_sprint_creation?) { |_project| false }
    view_context.define_singleton_method(:current_user) { current_user_value }
  end
end

RSpec.describe Backlogs::InboxComponent, type: :component do
  include Rails.application.routes.url_helpers

  shared_let(:project) { create(:project) }
  shared_let(:user) { create(:admin) }

  current_user { user }

  let(:work_packages) { WorkPackage.none }
  let(:show_all) { false }

  def render_component(**extra)
    render_inline(
      described_class.new(
        work_packages:,
        project:,
        current_user: user,
        **extra
      )
    )
  end

  def create_inbox_work_package(subject: "WP", position: nil)
    create(:work_package, subject:, project:, position:)
  end

  before do
    render_component(show_all:)
  end

  describe "container" do
    it "renders a Primer::Beta::BorderBox with the inbox DOM id" do
      expect(page).to have_css(".Box#inbox_#{project.id}")
    end

    it "mounts the Backlogs list controller with inbox metadata" do
      box = page.find(".Box#inbox_#{project.id}")

      expect(box["data-controller"]).to include("backlogs--dnd-list")
      expect(box["data-backlogs--dnd-list-target-id-value"]).to eq("inbox")
      expect(box["data-backlogs--dnd-list-target"]).to eq("container")
    end
  end

  describe "surface contract" do
    it "keeps the surface outlet contract aligned with the inbox list markup" do
      render_inline(
        Backlogs::BacklogListProbeComponent.new(
          project:,
          inbox_work_packages: work_packages,
          sprints: Agile::Sprint.none,
          stories_by_sprint_id: {},
          active_sprint_ids: [],
          show_all_backlog: show_all,
          current_user: user
        )
      )

      expect(page.find(".op-sprint-planning-container")["data-backlogs--dnd-surface-backlogs--dnd-list-outlet"])
        .to eq("[data-controller~='backlogs--dnd-list']")
    end
  end

  describe "empty state" do
    let(:work_packages) { WorkPackage.none }

    it "shows the blankslate heading and description" do
      expect(page).to have_css("h4", text: "Backlog inbox is empty")
      expect(page).to have_text("All open work packages in this project will automatically appear here.")
    end

    it "hides the counter" do
      expect(page).to have_css(".Counter", text: "0", visible: :hidden)
    end
  end

  describe "with work packages" do
    let(:wp1) { create_inbox_work_package(subject: "First item", position: 1) }
    let(:wp2) { create_inbox_work_package(subject: "Second item", position: 2) }
    let(:work_packages) { WorkPackage.where(id: [wp1.id, wp2.id]).order(:position) }

    it "renders a row for each work package", :aggregate_failures do
      expect(page).to have_css(".Box-row", count: 2)

      # renders the subject of each work package
      expect(page).to have_text("First item")
      expect(page).to have_text("Second item")
      expect(page).to have_css(".Box-row[data-backlogs--dnd-list-target='item']", count: 2)

      # does not show the blankslate
      expect(page).to have_no_css("h4", text: "Backlog inbox is empty")
    end

    it "shows the counter with the work package count" do
      expect(page).to have_css(".Counter", text: "2")
    end
  end

  describe "pagination" do
    let(:threshold) { described_class::PAGINATION_THRESHOLD }
    let(:first_page_size) { described_class::FIRST_PAGE_SIZE }
    let(:last_page_size) { described_class::LAST_PAGE_SIZE }

    context "when work packages do not exceed the threshold" do
      let(:work_packages) do
        wps = create_list(:work_package, threshold, project:)
        WorkPackage.where(id: wps.map(&:id))
      end

      it "renders all items without pagination" do
        expect(page).to have_css(".Box-row", count: threshold)
        # does not show a 'show more' link
        expect(page).to have_no_css("#inbox-more-row-#{project.id}")
      end
    end

    context "when work packages exceed the threshold" do
      let(:total) { threshold + 8 }
      let(:middle_count) { total - first_page_size - last_page_size }
      let(:work_packages) do
        wps = create_list(:work_package, total, project:)
        WorkPackage.where(id: wps.map(&:id)).order(:id)
      end

      it "renders only the first page and last page items (not all)" do
        expect(page).to have_css(".Box-row", count: first_page_size + last_page_size + 1) # +1 for "show more" row
        # shows a 'show more' link with the count of hidden items
        expect(page).to have_css("#inbox-more-row-#{project.id}")
        expect(page).to have_text("Show #{middle_count} more items")
      end
    end

    context "when show_all: true and work packages exceed threshold" do
      let(:show_all) { true }
      let(:total) { threshold + 3 }
      let(:work_packages) do
        wps = create_list(:work_package, total, project:)
        WorkPackage.where(id: wps.map(&:id))
      end

      it "renders all items without pagination" do
        expect(page).to have_css(".Box-row", count: total)
        # does not show a 'show more' link
        expect(page).to have_no_css("#inbox-more-row-#{project.id}")
      end
    end
  end
end
