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

RSpec.describe Projects::CopyFormComponent, type: :component do
  let(:source_project) { build_stubbed(:project) }
  let(:target_project) { Project.new(attributes_for(:project).except(:name)) }

  def render_component(**params)
    render_inline(described_class.new(source_project:, target_project:, **params))
    page
  end

  it "renders a form" do
    expect(render_component).to have_css "form"
  end

  describe "#identifier_suggestion_data" do
    it "mounts the Stimulus controller on the wrapper" do
      expect(render_component).to have_css("[data-controller='projects--identifier-suggestion']")
    end

    it "includes the suggestion URL" do
      expect(render_component).to have_css(
        "[data-projects--identifier-suggestion-url-value='/projects/identifier_suggestion']"
      )
    end

    it "includes the set_name_first translation" do
      translation = I18n.t("js.projects.identifier_suggestion.set_name_first")
      expect(render_component).to have_css(
        "[data-projects--identifier-suggestion-set-name-first-value='#{translation}']"
      )
    end

    context "with alphanumeric identifiers", with_settings: { work_packages_identifier: "alphanumeric" } do
      it "sets mode to semantic" do
        expect(render_component).to have_css("[data-projects--identifier-suggestion-mode-value='semantic']")
      end
    end

    context "with numeric identifiers", with_settings: { work_packages_identifier: "numeric" } do
      it "sets mode to legacy" do
        expect(render_component).to have_css("[data-projects--identifier-suggestion-mode-value='legacy']")
      end
    end
  end
end
