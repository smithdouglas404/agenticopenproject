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

RSpec.describe Overviews::Widgets::ProjectStatusComponent, type: :component do
  include Rails.application.routes.url_helpers

  def render_component(...)
    render_inline(described_class.new(...))
  end

  let(:project) { build_stubbed(:project, status_explanation: "**This project is in jeopardy!**") }
  let(:user) { build_stubbed(:user) }

  current_user { user }

  subject(:rendered_component) do
    render_component(project:, current_user:)
  end

  it "renders turbo-frame component wrapper" do
    expect(rendered_component).to have_element :"turbo-frame"
  end

  it "renders Projects Status Button component" do
    expect(rendered_component).to have_element id: "projects-status-button-component"
  end

  context "when user is not allowed to edit" do
    it "renders status description as formatted text" do
      expect(rendered_component).to have_css "p"
      expect(rendered_component).to have_css "strong", text: "This project is in jeopardy!"
    end
  end

  context "when user is allowed to edit" do
    before do
      mock_permissions_for(user) do |mock|
        mock.allow_in_project(:edit_project, project:)
      end
    end

    it "renders form" do
      expect(rendered_component).to have_element :form, method: :post,
                                                        action: project_widgets_project_status_path(project)
    end

    it "renders hidden method field" do
      expect(rendered_component).to have_field "_method", type: :hidden, with: "patch"
    end

    it "renders text area field" do
      expect(rendered_component).to have_element "opce-ckeditor-augmented-textarea",
                                                 "data-test-selector": "augmented-text-area-status_explanation"
    end
  end
end
