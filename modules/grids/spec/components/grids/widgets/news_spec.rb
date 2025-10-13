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

RSpec.describe Grids::Widgets::News, type: :component do
  include Rails.application.routes.url_helpers

  def render_component(...)
    render_inline(described_class.new(...))
  end

  let(:project) { nil }
  let(:user) { create(:admin) }

  current_user { user }

  subject(:rendered_component) do
    render_component(project)
  end

  it "renders turbo-frame component wrapper" do
    expect(rendered_component).to have_element :"turbo-frame"
  end

  context "for root" do
    context "with no news" do
      it "renders a message" do
        expect(rendered_component).to have_primer_text "Nothing new to report.", color: "subtle"
      end
    end

    context "with news" do
      let(:author) { create(:user) }
      let!(:news) { create_list(:news, 2, author:) }

      it "renders news items", :aggregate_failures do
        expect(rendered_component).to have_list_item(count: 2)
        expect(rendered_component).to have_list_item(position: 2) do |item|
          expect(item).to have_link href: news_path(news.first)
          expect(item).to have_content /Added by .+ on \d{2}\/\d{2}\/\d{4} \d{2}:\d{2} [AP]M/
          expect(item).to have_link href: user_path(author)
        end
      end
    end
  end

  context "with project" do
    let(:project) { create(:project) }

    context "with no news" do
      it "renders a message" do
        expect(rendered_component).to have_primer_text "Nothing new to report.", color: "subtle"
      end
    end

    context "with news" do
      let(:author) { create(:user) }
      let!(:news) { create_list(:news, 3, project:, author:) }

      it "renders news items", :aggregate_failures do
        expect(rendered_component).to have_list_item(count: 3)
        expect(rendered_component).to have_list_item(position: 3) do |item|
          expect(item).to have_link href: news_path(news.first)
          expect(item).to have_content /Added by .+ on \d{2}\/\d{2}\/\d{4} \d{2}:\d{2} [AP]M/
          expect(item).to have_link href: user_path(author)
        end
      end
    end
  end

  context "with project without news module enabled" do
    let(:project) { create(:project, enabled_module_names: [:wiki]) }

    it "does not render" do
      expect(rendered_component).not_to have_primer_text "Nothing new to report.", color: "subtle"
      expect(rendered_component).not_to have_list "News"
    end
  end
end
