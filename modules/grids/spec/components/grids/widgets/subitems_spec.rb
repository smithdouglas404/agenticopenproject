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

RSpec.describe Grids::Widgets::Subitems, type: :component do
  include Rails.application.routes.url_helpers

  def render_component(...)
    render_inline(described_class.new(...))
  end

  let(:project) { build_stubbed(:project) }
  let(:user) { build_stubbed(:user) }
  let(:params) { {} }

  current_user { user }

  subject(:rendered_component) do
    render_component(project, current_user:, **params)
  end

  context "with no children" do
    it "renders a message" do
      expect(rendered_component).to have_primer_text "There are no visible children.", color: "subtle"
    end
  end

  context "with children" do
    let(:project) { create(:project) }
    let!(:subprojects) { create_list(:project, 3, parent: project) }

    context "when visible to user" do
      let(:user) { create(:admin) }

      context "and a limit greater than the number of all subitems (default: 10)" do
        it "renders all subitems, without a 'view all' item", :aggregate_failures do
          expect(rendered_component).to have_list "Subitems" do |list|
            expect(list).to have_list_item count: 3, text: /My Project No. \d+/
            expect(list).to have_no_list_item text: "View all subitems"
          end
        end

        it "does not render 'view all' link" do
          expect(rendered_component).to have_no_link "View all subitems"
        end
      end

      context "and a limit less than the number of all subitems" do
        let(:params) { { limit: 2 } }

        it "renders specified subitems, along with a 'view all' item", :aggregate_failures do
          expect(rendered_component).to have_list "Subitems" do |list|
            expect(list).to have_list_item count: 2, text: /My Project No. \d+/
            expect(list).to have_list_item text: "View all subitems"
          end
        end

        it "renders 'view all' link to projects with parent filter", :aggregate_failures do
          expect(rendered_component).to have_link "View all subitems" do |link|
            uri = Addressable::URI.parse(link[:href])
            expect(uri.path).to eq projects_path
            expect(uri.query_values["filters"]).to be_json_eql %{[
              {"active":{"operator":"=","values":["t"]}},
              {"parent_id":{"operator":"=","values":[#{project.id}]}}
            ]}
          end
        end
      end
    end

    context "when not visible to user" do
      it "renders a message" do
        expect(rendered_component).to have_primer_text "There are no visible children.", color: "subtle"
      end
    end
  end
end
