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

RSpec.describe OpenProject::Common::WorkPackageCardBoxComponent, type: :component do
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
  let(:work_packages) { [] }
  let(:system_arguments) { {} }
  let(:header_arguments) { nil }
  let(:footer_content) { nil }

  subject(:rendered_component) do
    render_component(work_packages:, container:, system_arguments:)
  end

  def render_component(work_packages:, container:, system_arguments:)
    render_inline(
      described_class.new(work_packages:, project:, container:, current_user: user, **system_arguments)
    ) do |box|
      box.with_header(**header_arguments) if header_arguments
      box.with_empty_state(title: "Sprint 1 is empty", description: "Drag work packages here")
      box.with_footer { footer_content } if footer_content
    end
  end

  describe "Box shell" do
    it_behaves_like "rendering Box", row_count: 1, header: false, footer: false
    it_behaves_like "rendering Blank Slate", heading: "Sprint 1 is empty"
  end

  describe "container-derived attributes" do
    context "when container is a Sprint" do
      let(:container) { sprint }

      it "uses dom_id(sprint) as the box id" do
        expect(rendered_component).to have_css(".Box#sprint_#{sprint.id}")
      end

      it "uses a derived list id for the collapsible BorderBox body" do
        expect(rendered_component).to have_css("ul#sprint_#{sprint.id}-list")
      end

      it "uses the sprint drop-target id" do
        expect(rendered_component).to have_css(".Box[data-target-id='sprint:#{sprint.id}']")
      end

      it "uses container mirrorContainer as the drop target type" do
        expect(rendered_component).to have_css(".Box[data-generic-drag-and-drop-target='container mirrorContainer']")
      end

      it "does not emit a default test selector" do
        expect(rendered_component).to have_no_css(".Box[data-test-selector]")
      end
    end

    context "when container is a BacklogBucket" do
      let(:container) { backlog_bucket }

      it "uses dom_id(backlog_bucket) as the box id" do
        expect(rendered_component).to have_css(".Box#backlog_bucket_#{backlog_bucket.id}")
      end

      it "uses a derived list id for the collapsible BorderBox body" do
        expect(rendered_component).to have_css("ul#backlog_bucket_#{backlog_bucket.id}-list")
      end

      it "uses the backlog bucket drop-target id" do
        expect(rendered_component).to have_css(".Box[data-target-id='backlog_bucket:#{backlog_bucket.id}']")
      end

      it "uses container mirrorContainer as the drop target type" do
        expect(rendered_component).to have_css(".Box[data-generic-drag-and-drop-target='container mirrorContainer']")
      end

      it "does not emit a default test selector" do
        expect(rendered_component).to have_no_css(".Box[data-test-selector]")
      end
    end

    context "when container is nil (inbox)" do
      let(:container) { nil }

      it "uses inbox_<project.id> as the box id" do
        expect(rendered_component).to have_css(".Box#inbox_#{project.id}")
      end

      it "uses a derived list id for the collapsible BorderBox body" do
        expect(rendered_component).to have_css("ul#inbox_#{project.id}-list")
      end

      it "uses inbox as the drop-target id" do
        expect(rendered_component).to have_css(".Box[data-target-id='inbox']")
      end

      it "uses container mirrorContainer as the drop target type" do
        expect(rendered_component).to have_css(".Box[data-generic-drag-and-drop-target='container mirrorContainer']")
      end

      it "does not emit a default test selector" do
        expect(rendered_component).to have_no_css(".Box[data-test-selector]")
      end
    end

    it "always sets target_allowed_drag_type to story" do
      expect(rendered_component).to have_css(".Box[data-target-allowed-drag-type='story']")
    end

    context "when data[:test_selector] is provided by the caller" do
      let(:system_arguments) { { data: { test_selector: "custom-sprint-box" } } }

      it "passes the custom test selector through" do
        expect(rendered_component).to have_css(".Box[data-test-selector='custom-sprint-box']")
      end
    end
  end

  describe ":header slot" do
    context "when no header is supplied" do
      it "renders no Box-header" do
        expect(rendered_component).to have_no_css(".Box-header")
      end
    end

    context "when a header is supplied" do
      let(:header_arguments) { { title: "Sprint 1", count: 0 } }

      it_behaves_like "rendering Box", row_count: 1, header: true, footer: false

      it "renders the provided title" do
        expect(rendered_component).to have_heading "Sprint 1", level: 4
      end
    end
  end

  describe "fold state in the rendered header" do
    let(:header_arguments) { { title: "Sprint 1", count: 0 } }

    context "when the user prefers closed folds" do
      before do
        user.pref[:backlogs_versions_default_fold_state] = "closed"
      end

      it "renders the header as collapsed" do
        expect(rendered_component).to have_css ".CollapsibleHeader-triggerArea", aria: { expanded: "false" }
      end
    end

    context "when the user prefers open folds" do
      before do
        user.pref[:backlogs_versions_default_fold_state] = "open"
      end

      it "renders the header as expanded" do
        expect(rendered_component).to have_css ".CollapsibleHeader-triggerArea", aria: { expanded: "true" }
      end
    end
  end

  describe ":empty_state slot" do
    it "requires the empty_state slot" do
      expect do
        render_inline(described_class.new(work_packages: [], project:, container: sprint, current_user: user)) do |box|
          box.with_footer { "" }
        end
      end.to raise_error(ArgumentError, /empty_state/i)
    end

    it "renders the blankslate when work_packages is empty" do
      expect(rendered_component).to have_text("Sprint 1 is empty")
      expect(rendered_component).to have_text("Drag work packages here")
    end

    context "when there are work packages" do
      let(:work_packages) do
        [
          create(:work_package, project:, type: type_feature, status: default_status,
                                priority: default_priority, sprint:, position: 1)
        ]
      end

      it "does not render the blankslate" do
        expect(rendered_component).to have_no_css(".blankslate")
      end
    end
  end

  describe ":footer slot" do
    let(:footer_content) { "footer-content" }

    it "renders the footer row when supplied" do
      expect(rendered_component).to have_text("footer-content")
    end
  end

  describe "cards collection" do
    let(:work_packages) do
      [
        create(:work_package, subject: "WP A", project:, type: type_feature, status: default_status,
                              priority: default_priority, sprint:, position: 1),
        create(:work_package, subject: "WP B", project:, type: type_feature, status: default_status,
                              priority: default_priority, sprint:, position: 2)
      ]
    end

    it_behaves_like "rendering Box", row_count: 2, header: false, footer: false

    it "renders one row per work package" do
      expect(rendered_component).to have_text("WP A")
      expect(rendered_component).to have_text("WP B")
    end

    it "applies the card row attributes in the rendered HTML" do
      work_package = work_packages.first

      expect(rendered_component).to have_css(
        ".Box-row#work_package_#{work_package.id}.Box-row--clickable[data-test-selector='work-package-#{work_package.id}']"
      )
    end
  end
end
