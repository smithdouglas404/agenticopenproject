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

RSpec.describe Backlogs::MoveToSprintDialogComponent, type: :component do
  let(:project) { create(:project) }
  let(:work_package) { create(:work_package, project:) }
  let(:move_path) { Rails.application.routes.url_helpers.move_project_backlogs_inbox_path(project, work_package) }

  def render_component
    render_inline(described_class.new(work_package:, project:))
  end

  it "renders the dialog with the correct title" do
    render_component

    expect(page).to have_text(I18n.t(:"backlogs.move_to_sprint_dialog_component.title"))
  end

  it "renders a form targeting the move path via PUT" do
    render_component

    expect(page).to have_element(:form, action: move_path, method: "post")
    expect(page).to have_css("form[action='#{move_path}'] input[name='_method'][value='put']", visible: :all)
  end

  it "renders Cancel and Save buttons" do
    render_component

    expect(page).to have_button(I18n.t(:button_cancel))
    expect(page).to have_button(I18n.t(:button_move))
  end

  context "when in_planning and active sprints exist" do
    let!(:planning_sprint) { create(:agile_sprint, project:, name: "Planning Sprint", status: "in_planning") }
    let!(:active_sprint) { create(:agile_sprint, project:, name: "Active Sprint", status: "active") }

    it "lists them as select options with sprint: prefix values" do
      render_component

      expect(page).to have_css("option[value='sprint:#{planning_sprint.id}']", text: "Planning Sprint")
      expect(page).to have_css("option[value='sprint:#{active_sprint.id}']", text: "Active Sprint")
    end
  end

  context "when a completed sprint exists" do
    let!(:completed_sprint) { create(:agile_sprint, project:, name: "Old Sprint", status: "completed") }

    it "does not list the completed sprint" do
      render_component

      expect(page).to have_no_css("option", text: "Old Sprint")
    end
  end

  context "when a sprint belongs to a different project" do
    let!(:other_sprint) { create(:agile_sprint, project: create(:project), name: "Other Sprint") }

    it "does not list sprints from other projects" do
      render_component

      expect(page).to have_no_css("option", text: "Other Sprint")
    end
  end
end
