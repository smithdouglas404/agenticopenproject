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

RSpec.describe OpPrimer::DataTableComponent, type: :component do
  def render_component(**, &)
    render_inline(described_class.new(**), &)
  end

  let(:data) { build_stubbed_list(:work_package, 3) }

  shared_examples_for "rendering container" do
    it "renders scrollable-region" do
      expect(rendered_component).to have_element :"scrollable-region"
    end

    it "renders container and table classes" do
      expect(rendered_component).to have_css ".TableContainer .TableOverflowWrapper .Table"
    end
  end

  shared_examples_for "rendering head" do
    it "renders thead" do
      expect(rendered_component).to have_element :thead, role: "rowgroup"
    end

    it "renders thead classes", :aggregate_failures do
      expect(rendered_component).to have_css(".Table .TableHead .TableRow", count: 1) do |row|
        expect(row).to have_css ".TableHeader", count: 1
      end
    end
  end

  shared_examples_for "rendering body" do
    it "renders tbody" do
      expect(rendered_component).to have_element :tbody, role: "rowgroup"
    end

    it "renders tbody classes", :aggregate_failures do
      expect(rendered_component).to have_css(".Table .TableBody .TableRow", count: 3) do |row|
        expect(row).to have_css ".TableCell", count: 1
      end
    end
  end

  context "with minimal slots" do
    subject(:rendered_component) do
      render_component(data:) do |data_table|
        data_table.with_column(field: :subject, header: "Subject")
      end
    end

    include_examples "rendering container"

    it "renders table" do
      expect(rendered_component).to have_element :table, role: "table"
    end

    it_behaves_like "rendering head"
    it_behaves_like "rendering body"
  end

  context "without slots" do
    subject(:rendered_component) { render_component(data:) }

    it "renders nothing" do
      expect(rendered_component.to_s).to be_blank
    end
  end

  context "with title slot" do
    subject(:rendered_component) do
      render_component(data:) do |data_table|
        data_table.with_title { "Arbeitspakete" }
        data_table.with_column(field: :subject, header: "Subject")
      end
    end

    it "renders title (as h2 by default)" do
      expect(rendered_component).to have_element :h2, text: "Arbeitspakete"
    end

    include_examples "rendering container"

    it "renders scrollable-region with data attributes" do
      expect(rendered_component).to have_element :"scrollable-region" do |scrollable_region|
        labelled_by = page.find(:element, :h2, text: "Arbeitspakete")

        expect(labelled_by).not_to be_nil
        expect(scrollable_region[:"data-labelled-by"]).to eq labelled_by[:id]
      end
    end

    it "renders table with accessible name" do
      expect(rendered_component).to have_element :table, role: "table", accessible_name: "Arbeitspakete"
    end

    it_behaves_like "rendering head"
    it_behaves_like "rendering body"
  end

  context "with subtitle slot" do
    subject(:rendered_component) do
      render_component(data:) do |data_table|
        data_table.with_subtitle { "Workin' night and day" }
        data_table.with_column(field: :subject, header: "Subject")
      end
    end

    it "renders subtitle (as div by default)" do
      expect(rendered_component).to have_element :div, text: "Workin' night and day"
    end

    include_examples "rendering container"

    it "renders table with accessible description" do
      expect(rendered_component).to have_element :table, role: "table", accessible_description: "Workin' night and day"
    end

    it_behaves_like "rendering head"
    it_behaves_like "rendering body"
  end
end
