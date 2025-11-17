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

RSpec.describe Portfolios::DetailsComponent, type: :component do
  include Rails.application.routes.url_helpers
  include FavoriteHelper

  def render_component(...)
    render_inline(described_class.new(...))
  end

  let(:user) { create(:admin) }

  shared_let(:portfolio) do
    create(:portfolio,
           description: "portfolio description") do |portfolio|
      create(:project, parent: portfolio)
    end
  end
  shared_let(:program_a) do
    create(:program, parent: portfolio) do |program_a|
      create(:project, parent: program_a) do |project_a|
        create(:project, parent: project_a)
      end
    end
  end
  shared_let(:program_b) do
    create(:program, parent: portfolio) do |program_b|
      create(:project, parent: program_b)
      create(:project, parent: program_b)
    end
  end

  current_user { user }

  subject(:rendered_component) do
    render_component(portfolio:, current_user: user)
  end

  describe "portfolio" do
    it "renders the title as a link" do
      expect(subject).to have_element("a", text: portfolio.name) do |link|
        expect(link[:href]).to eq(project_overview_path(portfolio))
      end
    end

    it { expect(subject).to have_text(portfolio.description) }

    it "offers a button to favor the portfolio" do
      expect(subject).to have_test_selector("op-portfolios--favorite-button") do |link|
        expect(link[:href]).to eq(build_favorite_path(portfolio, format: :html))
      end
    end

    describe "displays the number of child programs and projects" do
      it { expect(subject).to have_text("2 programs") }
      it { expect(subject).to have_text("5 projects") }
    end

    describe "#updated_at" do
      before do
        allow(portfolio).to receive(:updated_at).and_return(1.month.ago)
      end

      it "shows when the portfolio was last updated" do
        expect(subject).to have_test_selector("op-portfolios--updated-at", text: "Updated about 1 month ago")
      end
    end
  end
end
