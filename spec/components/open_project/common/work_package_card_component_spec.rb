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

RSpec.describe OpenProject::Common::WorkPackageCardComponent, type: :component do
  include Rails.application.routes.url_helpers

  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:default_status) { create(:default_status) }
  shared_let(:default_priority) { create(:default_priority) }
  shared_let(:user) { create(:admin) }
  current_user { user }

  shared_let(:project) { create(:project, types: [type_feature]) }
  shared_let(:sprint) do
    create(:sprint, project:, name: "Sprint 1",
                    start_date: Date.yesterday, finish_date: Date.tomorrow)
  end
  shared_let(:backlog_bucket) { create(:backlog_bucket, project:, name: "Bucket A") }

  let(:container) { sprint }
  let(:work_package) do
    create(:work_package,
           project:,
           type: type_feature,
           status: default_status,
           priority: default_priority,
           subject: "Card subject",
           story_points: 5,
           position: 1,
           sprint:)
  end

  let(:component) do
    described_class.new(work_package:, project:, container:, current_user: user)
  end
  let(:menu_button_id) { "work_package_#{work_package.id}_menu-button" }

  subject(:rendered_component) do
    render_inline(component)
  end

  describe "card content" do
    it "renders the work-package info line (type + id)" do
      expect(rendered_component).to have_text("FEATURE")
      expect(rendered_component).to have_text("##{work_package.id}")
    end

    it "renders the subject in semibold text" do
      expect(rendered_component).to have_text("Card subject")
    end

    it "renders the story points label" do
      expect(rendered_component).to have_text("5 points", normalize_ws: true)
    end

    it "renders a WorkPackageCardComponent::Menu kebab" do
      expect(rendered_component).to have_element :"action-menu"
      expect(rendered_component).to have_button(menu_button_id)
    end

    it "uses the work package actions label" do
      expect(rendered_component).to have_button(
        menu_button_id,
        accessible_name: I18n.t("open_project.common.work_package_card_component.menu.label_actions")
      )
    end
  end

  describe "#row_args" do
    before do
      rendered_component
    end

    it "supplies the work-package dom_id" do
      expect(component.row_args[:id]).to eq("work_package_#{work_package.id}")
    end

    it "is keyboard-focusable" do
      expect(component.row_args[:tabindex]).to eq(0)
    end

    it "applies the standard row classes" do
      expect(component.row_args[:classes]).to include(
        "Box-row--hover-blue",
        "Box-row--focus-gray",
        "Box-row--clickable"
      )
    end

    it "carries the test selector" do
      expect(component.row_args[:data][:test_selector]).to eq("work-package-#{work_package.id}")
    end
  end

  describe "draggability" do
    before do
      rendered_component
    end

    context "when the user has :manage_sprint_items" do
      it "marks the row as draggable" do
        expect(component.row_args[:classes]).to include("Box-row--draggable")
        expect(component.row_args[:data]).to include(:draggable_id, :draggable_type, :drop_url)
      end
    end

    context "when the user lacks :manage_sprint_items" do
      let(:role) { create(:project_role, permissions: %i[view_sprints view_work_packages]) }
      let(:limited_user) { create(:user, member_with_roles: { project => role }) }
      let(:component) do
        described_class.new(work_package:, project:, container:, current_user: limited_user)
      end

      it "does not mark the row as draggable" do
        expect(component.row_args[:classes]).not_to include("Box-row--draggable")
        expect(component.row_args[:data]).not_to include(:draggable_id)
        expect(component.row_args[:data]).not_to include(:drop_url)
      end
    end
  end

  describe "URL derivation by container" do
    before do
      rendered_component
    end

    context "with container: a Sprint" do
      let(:container) { sprint }

      it "exposes split_url data derived from the work-package details path" do
        expect(component.row_args.dig(:data, :backlogs__story_split_url_value))
          .to end_with(project_backlogs_backlog_details_path(project, work_package))
      end

      it "exposes full_url data as the work-package show path" do
        expect(component.row_args.dig(:data, :backlogs__story_full_url_value)).to eq(work_package_path(work_package))
      end

      it "drops to the sprint move route" do
        expect(component.row_args.dig(:data, :drop_url))
          .to end_with(move_project_backlogs_work_package_path(project, sprint, work_package))
      end

      it "uses the sprint menu route for the kebab src" do
        expect(rendered_component).to have_element "include-fragment",
                                                   src: menu_project_backlogs_work_package_path(project, sprint,
                                                                                                work_package)
      end
    end

    context "with container: a BacklogBucket" do
      let(:container) { backlog_bucket }

      it "drops to the inbox move route" do
        expect(component.row_args.dig(:data, :drop_url))
          .to end_with(move_project_backlogs_inbox_path(project, work_package))
      end

      it "uses the inbox menu route for the kebab src" do
        expect(rendered_component).to have_element "include-fragment",
                                                   src: menu_project_backlogs_inbox_path(project, work_package)
      end
    end

    context "with container: nil (inbox)" do
      let(:container) { nil }

      it "drops to the inbox move route" do
        expect(component.row_args.dig(:data, :drop_url))
          .to end_with(move_project_backlogs_inbox_path(project, work_package))
      end

      it "uses the inbox menu route for the kebab src" do
        expect(rendered_component).to have_element "include-fragment",
                                                   src: menu_project_backlogs_inbox_path(project, work_package)
      end
    end
  end

  context "when params[:all] is true" do
    before do
      vc_test_controller.params[:all] = "1"
      rendered_component
    end

    it "propagates the all param through row_args and menu src" do
      expect(component.row_args.dig(:data, :backlogs__story_split_url_value)).to match(/all=1/)
      expect(component.row_args.dig(:data, :drop_url)).to match(/all=1/)
      expect(rendered_component).to have_element "include-fragment",
                                                 src: menu_project_backlogs_work_package_path(project, sprint,
                                                                                              work_package, all: "1")
    end
  end
end
