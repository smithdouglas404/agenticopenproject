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
  shared_let(:type_feature) { create(:type_feature) }
  shared_let(:default_status) { create(:default_status) }
  shared_let(:default_priority) { create(:default_priority) }

  shared_let(:project) { create(:project, types: [type_feature]) }

  let(:menu_src) { "/work_packages/#{work_package.id}/menu" }
  let(:work_package) do
    create(:work_package,
           project:,
           type: type_feature,
           status: default_status,
           priority: default_priority,
           subject: "Card subject",
           story_points: 5,
           position: 1,
           sprint: nil)
  end

  let(:component) do
    described_class.new(work_package:, menu_src:)
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

    it "uses the provided menu src" do
      expect(rendered_component).to have_element "include-fragment", src: menu_src
    end
  end
end
