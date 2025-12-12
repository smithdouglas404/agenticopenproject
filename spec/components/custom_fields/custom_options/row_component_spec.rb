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

RSpec.describe CustomFields::CustomOptions::RowComponent, type: :component do
  let(:custom_field) { create(:custom_field) }
  let(:table) do
    instance_double(
      CustomFields::CustomOptions::TableComponent,
      columns: %i[value default_value],
      custom_field:
    )
  end

  subject(:rendered_component) do
    render_in_view_context(
      described_class,
      custom_option,
      custom_field,
      table,
      self
    ) do |described_class, custom_option, custom_field, table, spec_context|
      primer_form_with(url: "/foo", model: custom_field) do |f|
        spec_context.allow(table).to spec_context.receive(:form).and_return(f)

        render(described_class.new(row: custom_option, row_counter: 0, table:))
      end
    end

    rendered_content # we want a string rather Nokogiri::HTML5.fragment to workaround it stripping <tr>
  end

  context "with new custom option" do
    let(:custom_option) { build(:custom_option, custom_field:) }

    it "renders row" do
      expect(rendered_component).to have_element :tr
    end

    it "renders cells" do
      expect(rendered_component).to have_element :td, count: 3
    end

    it "renders 'Value' input" do
      expect(rendered_component).to have_field "Value" do |field|
        expect(field["name"]).to eq "custom_field[custom_options_attributes][0][value]"
        expect(field["id"]).to eq "custom_field_custom_options_attributes_0_value"
      end
    end

    it "renders 'Default' input" do
      expect(rendered_component).to have_field "Default" do |field|
        expect(field["name"]).to eq "custom_field[custom_options_attributes][0][default_value]"
        expect(field["id"]).to eq "custom_field_custom_options_attributes_0_default_value"
      end
    end
  end

  context "with existing custom option" do
    let(:custom_option) { create(:custom_option, custom_field:) }

    it "renders row" do
      expect(rendered_component).to have_element :tr
    end

    it "renders cells" do
      expect(rendered_component).to have_element :td, count: 3
    end

    it "renders 'Value' input" do
      expect(rendered_component).to have_field "Value" do |field|
        expect(field["name"]).to eq "custom_field[custom_options_attributes][#{custom_option.id}][value]"
        expect(field["id"]).to eq "custom_field_custom_options_attributes_#{custom_option.id}_value"
      end
    end

    it "renders 'Default' input" do
      expect(rendered_component).to have_field "Default" do |select|
        expect(select["name"]).to eq "custom_field[custom_options_attributes][#{custom_option.id}][default_value]"
        expect(select["id"]).to eq "custom_field_custom_options_attributes_#{custom_option.id}_default_value"
      end
    end
  end
end
