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
#
require "rails_helper"

RSpec.describe Portfolios::DetailsComponent, type: :component do
  include Rails.application.routes.url_helpers
  include FavoriteHelper

  def render_component(...)
    render_inline(described_class.new(...))
  end

  let(:user) { build_stubbed(:user) }
  let(:program_a) do
    build_stubbed(:program) do |p|
      allow(p).to receive(:descendants).and_return([build_stubbed(:project)])
    end
  end
  let(:program_b) do
    build_stubbed(:program) do |p|
      allow(p).to receive(:descendants).and_return([build_stubbed(:project), build_stubbed(:project)])
    end
  end
  let(:project) do
    build_stubbed(:project) do |p|
      allow(p).to receive(:descendants).and_return([build_stubbed(:project)])
    end
  end
  let(:portfolio) do
    build_stubbed(:portfolio,
                  description: "portfolio description",
                  updated_at: 1.month.ago) do |p|
      allow(p).to receive(:descendants).and_return([program_a, program_b, project])
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

    describe "displays a count of child elements" do
      it { expect(subject).to have_text("2 programs") }
      it { expect(subject).to have_text("5 projects") }
    end

    it "shows when it was last updated" do
      expect(subject).to have_test_selector("op-portfolios--updated-at", text: "Updated about 1 month ago")
    end
  end
end
