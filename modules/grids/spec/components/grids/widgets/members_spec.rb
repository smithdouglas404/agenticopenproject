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

RSpec.describe Grids::Widgets::Members, type: :component do
  include Rails.application.routes.url_helpers

  def render_component(...)
    render_inline(described_class.new(...))
  end

  let(:project) { nil }
  let(:user) { nil }

  current_user { user }

  subject(:rendered_component) do
    render_component(project)
  end

  context "with permissions" do
    let(:project) { create(:project) }
    let(:user) { create(:admin) }

    context "with no members" do
      it "does render" do
        expect(rendered_component).to have_content "No visible members."
      end
    end

    context "with members" do
      let(:member) { create(:user, member_with_permissions: { project => %i[view_members] }) }

      before do
        member
      end

      it "renders turbo-frame component wrapper" do
        expect(rendered_component).to have_element :"turbo-frame"
      end

      it "renders members items", :aggregate_failures do
        expect(rendered_component).to have_element class: "op-widget-box--body" do |body|
          expect(body).to have_link href: project_members_path(project)
          expect(body).to have_element :"opce-principal"
        end
      end
    end
  end

  context "without permissions" do
    let(:project) { create(:project) }
    let(:user) { create(:anonymous) }

    it "does not render" do
      expect(rendered_component).not_to have_element id: "grids-widgets-members-box"
    end
  end
end
